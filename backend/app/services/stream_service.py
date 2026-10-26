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

    def _search_and_resolve_sc(self, query: str) -> Tuple[Optional[str], Optional[int]]:
        """
        Searches SoundCloud for the query, iterates entries, and returns the first playable stream URL (skipping DRM tracks).
        """
        ydl_search_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': True,
            'socket_timeout': 6,
        }
        try:
            with yt_dlp.YoutubeDL(ydl_search_opts) as ydl:
                info = ydl.extract_info(f"scsearch5:{query}", download=False)
                entries = info.get('entries', []) if info else []
                for entry in entries:
                    if not entry:
                        continue
                    url = entry.get('url') or entry.get('webpage_url')
                    if not url:
                        continue
                    try:
                        stream_opts = {
                            'format': 'bestaudio/best',
                            'noplaylist': True,
                            'quiet': True,
                            'no_warnings': True,
                            'socket_timeout': 6,
                        }
                        with yt_dlp.YoutubeDL(stream_opts) as stream_ydl:
                            s_info = stream_ydl.extract_info(url, download=False)
                            if s_info and s_info.get('url'):
                                return s_info.get('url'), s_info.get('duration')
                    except Exception:
                        continue
        except Exception:
            pass
        return None, None

    def get_source_url(self, track_id: str) -> Tuple[str, Optional[int]]:
        """
        Resolves direct audio stream URL and approximate duration via yt-dlp.
        Supports:
        - yn_sp_<query> (Spotify matching to SoundCloud/YT)
        - yn_yt_<id> (YouTube / YouTube Music with SoundCloud fallback)
        - yn_sc_<url> (SoundCloud with DRM auto-skip)
        - raw youtube / soundcloud URL
        """
        # 1. Spotify track: query-based audio matching
        if track_id.startswith("yn_sp_"):
            query = track_id.replace("yn_sp_", "")
            stream_url, dur = self._search_and_resolve_sc(query)
            if stream_url:
                return stream_url, dur
            raise HTTPException(status_code=404, detail="Audio stream not found for Spotify track")

        # 2. SoundCloud track
        if track_id.startswith("yn_sc_"):
            sc_target = track_id.replace("yn_sc_", "")
            target = sc_target if sc_target.startswith("http") else f"https://api.soundcloud.com/tracks/{sc_target}"
            try:
                ydl_opts = {
                    'format': 'bestaudio/best',
                    'noplaylist': True,
                    'quiet': True,
                    'no_warnings': True,
                    'socket_timeout': 6,
                }
                with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                    info = ydl.extract_info(target, download=False)
                    if info and info.get('url'):
                        return info.get('url'), info.get('duration')
            except Exception:
                pass
            
            # Fallback search if direct SC track hit DRM
            query = sc_target.replace("https://api.soundcloud.com/tracks/", "").replace("https://soundcloud.com/", "").replace("-", " ")
            stream_url, dur = self._search_and_resolve_sc(query)
            if stream_url:
                return stream_url, dur
            raise HTTPException(status_code=404, detail="SoundCloud audio stream unavailable")

        # 3. YouTube track
        if track_id.startswith("yn_yt_"):
            video_id = track_id.replace("yn_yt_", "")
            target = f"https://www.youtube.com/watch?v={video_id}"
            ydl_opts = {
                'format': 'bestaudio/best',
                'noplaylist': True,
                'quiet': True,
                'no_warnings': True,
                'socket_timeout': 6,
                'extractor_args': {
                    'youtube': {
                        'player_client': ['android', 'ios', 'web_embedded']
                    }
                }
            }
            try:
                with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                    info = ydl.extract_info(target, download=False)
                    if info and info.get('url'):
                        return info.get('url'), info.get('duration')
            except Exception as yt_err:
                # If YouTube fails on datacenter IP, fallback to SoundCloud audio search!
                title = None
                try:
                    with yt_dlp.YoutubeDL({'quiet': True, 'extract_flat': True, 'socket_timeout': 4}) as flat_ydl:
                        flat_info = flat_ydl.extract_info(target, download=False)
                        if flat_info:
                            title = flat_info.get('title')
                except Exception:
                    pass

                if title:
                    stream_url, dur = self._search_and_resolve_sc(title)
                    if stream_url:
                        return stream_url, dur
                raise HTTPException(status_code=404, detail=f"YouTube audio stream unavailable: {str(yt_err)}")

        # 4. Raw URL
        ydl_opts = {'format': 'bestaudio/best', 'noplaylist': True, 'quiet': True}
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(track_id, download=False)
            if info and info.get('url'):
                return info.get('url'), info.get('duration')
        raise HTTPException(status_code=404, detail="Audio stream not found")

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
