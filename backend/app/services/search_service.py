import asyncio
from typing import List, Optional
from pydantic import BaseModel
import yt_dlp
from app.core.config import settings

class TrackItem(BaseModel):
    id: str
    title: str
    artist: str
    album: Optional[str] = None
    duration_ms: int = 0
    artwork_url: Optional[str] = None
    source: str  # "youtube", "soundcloud", "spotify"
    stream_url: str

class SearchService:
    def __init__(self):
        pass

    async def search_all(self, query: str, limit_per_source: int = 10) -> List[TrackItem]:
        loop = asyncio.get_event_loop()
        
        # Parallel search across sources
        sc_future = loop.run_in_executor(None, self._search_soundcloud_ytdlp, query, limit_per_source)
        yt_future = loop.run_in_executor(None, self._search_ytmusic_safe, query, limit_per_source)

        sc_results, yt_results = await asyncio.gather(
            sc_future,
            yt_future,
            return_exceptions=True
        )

        results: List[TrackItem] = []
        if isinstance(sc_results, list):
            results.extend(sc_results)
        if isinstance(yt_results, list):
            results.extend(yt_results)

        return results

    def _search_soundcloud_ytdlp(self, query: str, limit: int) -> List[TrackItem]:
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': True,
            'socket_timeout': 5,
        }
        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(f"scsearch{limit}:{query}", download=False)
                if not info or 'entries' not in info:
                    return []
                
                tracks: List[TrackItem] = []
                for entry in info['entries']:
                    if not entry:
                        continue
                    url = entry.get('url') or entry.get('webpage_url')
                    title = entry.get('title', 'Unknown Title')
                    uploader = entry.get('uploader') or entry.get('channel') or 'SoundCloud Artist'
                    duration = entry.get('duration')
                    duration_ms = int(duration * 1000) if duration else 0
                    thumbnails = entry.get('thumbnails', [])
                    artwork = thumbnails[-1].get('url') if thumbnails else None

                    import re
                    num_id = entry.get('id')
                    if not num_id and url:
                        m = re.search(r'\d{6,}', str(url))
                        if m:
                            num_id = m.group(0)
                    track_id = f"yn_sc_{num_id}" if num_id else f"yn_sc_{url}"

                    tracks.append(TrackItem(
                        id=track_id,
                        title=title,
                        artist=uploader,
                        album=None,
                        duration_ms=duration_ms,
                        artwork_url=artwork,
                        source="soundcloud",
                        stream_url=f"/api/v1/stream/{track_id}"
                    ))
                return tracks
        except Exception:
            return []

    def _search_ytmusic_safe(self, query: str, limit: int) -> List[TrackItem]:
        try:
            from ytmusicapi import YTMusic
            yt = YTMusic()
            search_res = yt.search(query, filter="songs", limit=limit)
            tracks: List[TrackItem] = []
            
            for item in search_res:
                video_id = item.get("videoId")
                if not video_id:
                    continue
                
                title = item.get("title", "Unknown Title")
                artists = ", ".join([a.get("name", "") for a in item.get("artists", [])]) or "Unknown Artist"
                album = item.get("album", {}).get("name") if item.get("album") else None
                duration_seconds = item.get("duration_seconds")
                duration_ms = (duration_seconds * 1000) if duration_seconds else 0
                thumbnails = item.get("thumbnails", [])
                artwork_url = thumbnails[-1].get("url") if thumbnails else None

                track_id = f"yn_yt_{video_id}"
                tracks.append(TrackItem(
                    id=track_id,
                    title=title,
                    artist=artists,
                    album=album,
                    duration_ms=duration_ms,
                    artwork_url=artwork_url,
                    source="youtube",
                    stream_url=f"/api/v1/stream/{track_id}"
                ))
            return tracks
        except Exception:
            return []

search_service = SearchService()
