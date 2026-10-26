import asyncio
from typing import List, Dict, Any
from pydantic import BaseModel
from ytmusicapi import YTMusic
from app.services.search_service import TrackItem

class ShelfSection(BaseModel):
    title: str
    items: List[TrackItem]

class FeedResponse(BaseModel):
    trending: List[TrackItem]
    shelves: List[ShelfSection]

class FeedService:
    def __init__(self):
        self._ytmusic = None
        self._charts_cache = None

    def _get_ytmusic(self) -> YTMusic:
        if self._ytmusic is None:
            self._ytmusic = YTMusic()
        return self._ytmusic

    async def get_home_feed(self) -> FeedResponse:
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self._build_home_feed)

    def _build_home_feed(self) -> FeedResponse:
        yt = self._get_ytmusic()
        trending_tracks: List[TrackItem] = []
        shelves: List[ShelfSection] = []

        # 1. Fetch Charts
        try:
            charts = yt.get_charts(country="US")
            videos = charts.get("videos", {}).get("items", []) or charts.get("tracks", {}).get("items", [])
            for item in videos[:15]:
                video_id = item.get("videoId")
                if not video_id:
                    continue
                artists = ", ".join([a.get("name", "") for a in item.get("artists", [])]) or "Top Chart"
                thumbnails = item.get("thumbnails", [])
                artwork_url = thumbnails[-1].get("url") if thumbnails else None
                
                track_id = f"yn_yt_{video_id}"
                trending_tracks.append(TrackItem(
                    id=track_id,
                    title=item.get("title", "Unknown"),
                    artist=artists,
                    album="Global Top Hits",
                    duration_ms=0,
                    artwork_url=artwork_url,
                    source="youtube",
                    stream_url=f"/api/v1/stream/{track_id}"
                ))
        except Exception:
            pass

        # Fallback if charts empty: search popular hits
        if not trending_tracks:
            try:
                search_res = yt.search("Top Hits 2026", filter="songs", limit=15)
                for item in search_res:
                    video_id = item.get("videoId")
                    if not video_id:
                        continue
                    artists = ", ".join([a.get("name", "") for a in item.get("artists", [])]) or "Top Hits"
                    thumbnails = item.get("thumbnails", [])
                    artwork_url = thumbnails[-1].get("url") if thumbnails else None
                    track_id = f"yn_yt_{video_id}"
                    trending_tracks.append(TrackItem(
                        id=track_id,
                        title=item.get("title", "Unknown"),
                        artist=artists,
                        album="Top Trending",
                        duration_ms=0,
                        artwork_url=artwork_url,
                        source="youtube",
                        stream_url=f"/api/v1/stream/{track_id}"
                    ))
            except Exception:
                pass

        # 2. Genre Shelves: Electronic & Chill
        for genre, query in [("Electronic & Dance", "EDM electronic hits"), ("Chill & Lo-Fi", "lofi chill beats")]:
            try:
                res = yt.search(query, filter="songs", limit=8)
                items: List[TrackItem] = []
                for item in res:
                    video_id = item.get("videoId")
                    if not video_id:
                        continue
                    artists = ", ".join([a.get("name", "") for a in item.get("artists", [])]) or "Artist"
                    thumbnails = item.get("thumbnails", [])
                    artwork_url = thumbnails[-1].get("url") if thumbnails else None
                    track_id = f"yn_yt_{video_id}"
                    items.append(TrackItem(
                        id=track_id,
                        title=item.get("title", "Unknown"),
                        artist=artists,
                        album=genre,
                        duration_ms=0,
                        artwork_url=artwork_url,
                        source="youtube",
                        stream_url=f"/api/v1/stream/{track_id}"
                    ))
                if items:
                    shelves.append(ShelfSection(title=genre, items=items))
            except Exception:
                pass

        return FeedResponse(trending=trending_tracks, shelves=shelves)

    async def get_recommendations_for_track(self, track_id: str, limit: int = 15) -> List[TrackItem]:
        video_id = track_id.replace("yn_yt_", "").replace("yn_sc_", "")
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self._get_radio_tracks, video_id, limit)

    def _get_radio_tracks(self, video_id: str, limit: int) -> List[TrackItem]:
        try:
            yt = self._get_ytmusic()
            watch = yt.get_watch_playlist(videoId=video_id, limit=limit)
            tracks: List[TrackItem] = []
            for item in watch.get("tracks", []):
                vid = item.get("videoId")
                if not vid or vid == video_id:
                    continue
                artists = ", ".join([a.get("name", "") for a in item.get("artists", [])]) or "Similar Artist"
                thumbnails = item.get("thumbnails", [])
                artwork_url = thumbnails[-1].get("url") if thumbnails else None
                tid = f"yn_yt_{vid}"
                tracks.append(TrackItem(
                    id=tid,
                    title=item.get("title", "Unknown"),
                    artist=artists,
                    album=item.get("album", {}).get("name") if item.get("album") else None,
                    duration_ms=0,
                    artwork_url=artwork_url,
                    source="youtube",
                    stream_url=f"/api/v1/stream/{tid}"
                ))
            return tracks
        except Exception:
            return []

feed_service = FeedService()
