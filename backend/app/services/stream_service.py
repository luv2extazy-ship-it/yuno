import os
import asyncio
import hashlib
from typing import Optional, Tuple
from pathlib import Path
import yt_dlp
import httpx
from fastapi import Request, HTTPException
from fastapi.responses import Response, StreamingResponse
from app.core.config import settings

class StreamService:
    def __init__(self):
        self.cache_dir = Path(settings.CACHE_DIR)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self._url_cache = {}  # track_id -> direct_url (cached for 30m)

    def _get_cache_path(self, track_id: str) -> Path:
        safe_id = hashlib.md5(track_id.encode()).hexdigest()
        return self.cache_dir / f"{safe_id}.mp3"

    def get_source_url(self, track_id: str) -> Tuple[str, Optional[int]]:
        """
        Resolves direct audio stream URL and approximate duration via yt-dlp.
        Supports:
        - yn_yt_<id> (YouTube / YouTube Music)
        - yn_sc_<url> (SoundCloud)
        - raw youtube / soundcloud URL
        """
        target = track_id
        if track_id.startswith("yn_yt_"):
            video_id = track_id.replace("yn_yt_", "")
            target = f"https://www.youtube.com/watch?v={video_id}"
        elif track_id.startswith("yn_sc_"):
            sc_id = track_id.replace("yn_sc_", "")
            target = sc_id if sc_id.startswith("http") else f"https://api.soundcloud.com/tracks/{sc_id}"

        ydl_opts = {
            'format': 'bestaudio/best',
            'noplaylist': True,
            'quiet': True,
            'no_warnings': True,
            'extract_flat': False,
        }

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(target, download=False)
            if not info:
                raise HTTPException(status_code=404, detail="Audio stream not found")
            
            # Prefer direct audio stream url
            stream_url = info.get('url')
            duration = info.get('duration')
            return stream_url, duration

    async def get_stream_response(self, track_id: str, request: Request) -> Response:
        cache_file = self._get_cache_path(track_id)

        # 1. If file is cached locally on disk
        if cache_file.exists() and cache_file.stat().st_size > 0:
            return self._serve_local_file(cache_file, request)

        # 2. Extract direct stream URL
        stream_url = self._url_cache.get(track_id)
        if not stream_url:
            loop = asyncio.get_event_loop()
            try:
                stream_url, _ = await loop.run_in_executor(None, self.get_source_url, track_id)
                self._url_cache[track_id] = stream_url
            except Exception as e:
                raise HTTPException(status_code=404, detail=f"Failed to extract audio stream: {str(e)}")

        # 3. Stream from remote CDN with Range forwarding
        range_header = request.headers.get("Range")
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
        if range_header:
            headers["Range"] = range_header

        client = httpx.AsyncClient(timeout=15.0, follow_redirects=True)
        try:
            req = client.build_request("GET", stream_url, headers=headers)
            res = await client.send(req, stream=True)
        except Exception as e:
            await client.aclose()
            # Invalidate cached direct URL
            self._url_cache.pop(track_id, None)
            raise HTTPException(status_code=502, detail=f"CDN connection error: {str(e)}")

        async def stream_generator():
            try:
                async for chunk in res.aiter_bytes(chunk_size=65536):
                    yield chunk
            finally:
                await res.aclose()
                await client.aclose()

        response_headers = {
            "Accept-Ranges": "bytes",
            "Content-Type": res.headers.get("Content-Type", "audio/mpeg"),
        }
        if "Content-Range" in res.headers:
            response_headers["Content-Range"] = res.headers["Content-Range"]
        if "Content-Length" in res.headers:
            response_headers["Content-Length"] = res.headers["Content-Length"]

        # Trigger background caching if not already running
        asyncio.create_task(self._background_cache_track(track_id, stream_url, cache_file))

        status_code = res.status_code if res.status_code in (200, 206) else 200
        return StreamingResponse(
            stream_generator(),
            status_code=status_code,
            headers=response_headers,
            media_type=response_headers["Content-Type"]
        )

    async def _background_cache_track(self, track_id: str, stream_url: str, cache_file: Path):
        temp_file = cache_file.with_suffix(".tmp")
        if cache_file.exists() or temp_file.exists():
            return
        
        try:
            temp_file.touch()
            async with httpx.AsyncClient(timeout=60.0, follow_redirects=True) as client:
                async with client.stream("GET", stream_url) as resp:
                    if resp.status_code == 200:
                        with open(temp_file, "wb") as f:
                            async for chunk in resp.aiter_bytes(chunk_size=131072):
                                f.write(chunk)
                        temp_file.replace(cache_file)
        except Exception:
            if temp_file.exists():
                temp_file.unlink(missing_ok=True)

    def _serve_local_file(self, file_path: Path, request: Request) -> Response:
        file_size = file_path.stat().st_size
        range_header = request.headers.get("Range")

        if not range_header:
            def file_iter():
                with open(file_path, "rb") as f:
                    while chunk := f.read(65536):
                        yield chunk
            return StreamingResponse(
                file_iter(),
                status_code=200,
                headers={
                    "Content-Length": str(file_size),
                    "Content-Type": "audio/mpeg",
                    "Accept-Ranges": "bytes"
                }
            )

        # Parse range: "bytes=start-end"
        try:
            byte_range = range_header.replace("bytes=", "").split("-")
            start = int(byte_range[0]) if byte_range[0] else 0
            end = int(byte_range[1]) if byte_range[1] else file_size - 1
            end = min(end, file_size - 1)
        except ValueError:
            raise HTTPException(status_code=416, detail="Invalid Range header")

        length = end - start + 1

        def range_iter():
            with open(file_path, "rb") as f:
                f.seek(start)
                bytes_left = length
                while bytes_left > 0:
                    read_size = min(bytes_left, 65536)
                    data = f.read(read_size)
                    if not data:
                        break
                    bytes_left -= len(data)
                    yield data

        return StreamingResponse(
            range_iter(),
            status_code=206,
            headers={
                "Content-Range": f"bytes {start}-{end}/{file_size}",
                "Content-Length": str(length),
                "Content-Type": "audio/mpeg",
                "Accept-Ranges": "bytes"
            }
        )

stream_service = StreamService()
