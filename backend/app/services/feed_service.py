import time
import asyncio
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
from ytmusicapi import YTMusic
import yt_dlp
from app.services.search_service import TrackItem

class ShelfSection(BaseModel):
    title: str
    items: List[TrackItem]

class FeedResponse(BaseModel):
    trending: List[TrackItem]
    shelves: List[ShelfSection]

# Curated top Spotify hits (Russian & Global) with verified high-res artwork
SPOTIFY_RU_HITS = [
    {
        "title": "I Got Love",
        "artist": "Miyagi & Эндшпиль, Рем Дигга",
        "album": "Hajime, Pt. 2",
        "artwork": "https://i.scdn.co/image/ab67616d0000b273410712a2a0eb94754ab8da96",
        "duration_ms": 275000,
    },
    {
        "title": "Самый пьяный округ в районе",
        "artist": "MACAN",
        "album": "12",
        "artwork": "https://i.scdn.co/image/ab67616d0000b27339e144aee56a33c2a38b2540",
        "duration_ms": 156000,
    },
    {
        "title": "Million",
        "artist": "Big Baby Tape, Kizaru",
        "album": "BANDANA I",
        "artwork": "https://i.scdn.co/image/ab67616d0000b2736468a2bf18b3d68bc93a9366",
        "duration_ms": 134000,
    },
    {
        "title": "По барам",
        "artist": "ANNA ASTI",
        "album": "Феникс",
        "artwork": "https://i.scdn.co/image/ab67616d0000b273873e3a478be2a89cb5ce054b",
        "duration_ms": 238000,
    },
    {
        "title": "Вороны",
        "artist": "Xcho",
        "album": "CROSS",
        "artwork": "https://i.scdn.co/image/ab67616d0000b273db0f670e30327f2f11181735",
        "duration_ms": 182000,
    },
    {
        "title": "Тесно",
        "artist": "Aarne, BUSHIDO ZHO, ANIKV",
        "album": "AA LANGUAGE",
        "artwork": "https://i.scdn.co/image/ab67616d0000b27385ba805eec061ca81d3ee502",
        "duration_ms": 154000,
    },
    {
        "title": "Огней",
        "artist": "SALUKI",
        "album": "WILD EA$T",
        "artwork": "https://i.scdn.co/image/ab67616d0000b273e9112df600b3e77f0fe67557",
        "duration_ms": 169000,
    },
    {
        "title": "Положение",
        "artist": "Скриптонит",
        "album": "Праздник на улице 36",
        "artwork": "https://i.scdn.co/image/ab67616d0000b2731c3fcda1df8a14b0b1fe2a3f",
        "duration_ms": 284000,
    },
]

SPOTIFY_GLOBAL_HITS = [
    {
        "title": "Blinding Lights",
        "artist": "The Weeknd",
        "album": "After Hours",
        "artwork": "https://i.scdn.co/image/ab67616d0000b2738863bc11d2aa12b54f5aeb36",
        "duration_ms": 200000,
    },
    {
        "title": "Training Season",
        "artist": "Dua Lipa",
        "album": "Radical Optimism",
        "artwork": "https://i.scdn.co/image/ab67616d0000b273413eb44747eb4f58c70757bc",
        "duration_ms": 209000,
    },
    {
        "title": "Birds of a Feather",
        "artist": "Billie Eilish",
        "album": "HIT ME HARD AND SOFT",
        "artwork": "https://i.scdn.co/image/ab67616d0000b27371d62ea7ea8a5be92d3c1f62",
        "duration_ms": 190000,
    },
    {
        "title": "Starboy",
        "artist": "The Weeknd, Daft Punk",
        "album": "Starboy",
        "artwork": "https://i.scdn.co/image/ab67616d0000b2734718e2b124f79258be7bc452",
        "duration_ms": 230000,
    },
]

# Fast fallback YouTube tracks for instant load
YT_RU_PRESET = [
    {"id": "yn_yt_BLZWkjBXfN8", "title": "In The End", "artist": "Linkin Park", "album": "Hybrid Theory", "artwork": "https://i.ytimg.com/vi/BLZWkjBXfN8/hqdefault.jpg"},
    {"id": "yn_yt_9bZkp7q19f0", "title": "Gangnam Style", "artist": "PSY", "album": "Psy 6 (Six Rules)", "artwork": "https://i.ytimg.com/vi/9bZkp7q19f0/hqdefault.jpg"},
    {"id": "yn_yt_fJ9rUzIMcZQ", "title": "Bohemian Rhapsody", "artist": "Queen", "album": "A Night at the Opera", "artwork": "https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg"},
]

class FeedService:
    def __init__(self):
        self._ytmusic = None
        self._cache = {}  # key -> {"data": FeedResponse, "time": timestamp}

    def _get_ytmusic(self) -> YTMusic:
        if self._ytmusic is None:
            self._ytmusic = YTMusic()
        return self._ytmusic

    async def get_home_feed(self, country: str = "RU", lang: str = "ru") -> FeedResponse:
        cache_key = f"{country}_{lang}"
        cached = self._cache.get(cache_key)
        if cached and (time.time() - cached["time"] < 900):  # 15 minutes cache
            return cached["data"]

        loop = asyncio.get_event_loop()
        res = await loop.run_in_executor(None, self._build_home_feed, country.upper(), lang.lower())
        self._cache[cache_key] = {"data": res, "time": time.time()}
        return res

    def _build_home_feed(self, country: str, lang: str) -> FeedResponse:
        is_ru = country in ("RU", "BY", "KZ", "UA", "CIS") or lang.startswith("ru")

        # 1. Spotify Tracks (Curated popular hits)
        spotify_pool = SPOTIFY_RU_HITS if is_ru else SPOTIFY_GLOBAL_HITS
        spotify_tracks: List[TrackItem] = []
        for s in spotify_pool:
            tid = f"yn_sp_{s['artist']} - {s['title']}"
            spotify_tracks.append(TrackItem(
                id=tid,
                title=s["title"],
                artist=s["artist"],
                album=s["album"],
                duration_ms=s["duration_ms"],
                artwork_url=s["artwork"],
                source="spotify",
                stream_url=f"/api/v1/stream?track_id={tid}"
            ))

        # 2. SoundCloud Tracks
        soundcloud_tracks: List[TrackItem] = []
        try:
            query = "русский рэп чарт" if is_ru else "top electronic hits"
            ydl_opts = {'quiet': True, 'extract_flat': True, 'socket_timeout': 3}
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(f"scsearch8:{query}", download=False)
                for entry in info.get("entries", []):
                    if not entry:
                        continue
                    url = entry.get("url") or entry.get("webpage_url")
                    title = entry.get("title", "SoundCloud Track")
                    uploader = entry.get("uploader") or entry.get("channel") or "SoundCloud"
                    duration = entry.get("duration")
                    duration_ms = int(duration * 1000) if duration else 0
                    thumbs = entry.get("thumbnails", [])
                    artwork = thumbs[-1].get("url") if thumbs else None
                    tid = f"yn_sc_{url}"
                    soundcloud_tracks.append(TrackItem(
                        id=tid,
                        title=title,
                        artist=uploader,
                        album="SoundCloud Trending",
                        duration_ms=duration_ms,
                        artwork_url=artwork,
                        source="soundcloud",
                        stream_url=f"/api/v1/stream?track_id={tid}"
                    ))
        except Exception:
            pass

        # 3. YouTube Music Tracks
        yt_tracks: List[TrackItem] = []
        try:
            yt = self._get_ytmusic()
            charts = yt.get_charts(country="RU" if is_ru else country)
            videos = charts.get("videos", {}).get("items", []) or charts.get("tracks", {}).get("items", [])
            for item in videos[:10]:
                vid = item.get("videoId")
                if not vid:
                    continue
                artists = ", ".join([a.get("name", "") for a in item.get("artists", [])]) or "Top Chart"
                thumbs = item.get("thumbnails", [])
                artwork_url = thumbs[-1].get("url") if thumbs else None
                tid = f"yn_yt_{vid}"
                yt_tracks.append(TrackItem(
                    id=tid,
                    title=item.get("title", "Unknown"),
                    artist=artists,
                    album="YouTube Charts",
                    duration_ms=0,
                    artwork_url=artwork_url,
                    source="youtube",
                    stream_url=f"/api/v1/stream?track_id={tid}"
                ))
        except Exception:
            pass

        if not yt_tracks:
            for p in YT_RU_PRESET:
                yt_tracks.append(TrackItem(
                    id=p["id"],
                    title=p["title"],
                    artist=p["artist"],
                    album=p["album"],
                    duration_ms=0,
                    artwork_url=p["artwork"],
                    source="youtube",
                    stream_url=f"/api/v1/stream?track_id={p['id']}"
                ))

        # 4. Create Interleaved Mixed Trending List (Spotify + YouTube + SoundCloud)
        trending: List[TrackItem] = []
        max_len = max(len(spotify_tracks), len(yt_tracks), len(soundcloud_tracks))
        for i in range(max_len):
            if i < len(spotify_tracks):
                trending.append(spotify_tracks[i])
            if i < len(yt_tracks):
                trending.append(yt_tracks[i])
            if i < len(soundcloud_tracks):
                trending.append(soundcloud_tracks[i])

        # 5. Shelves
        shelves: List[ShelfSection] = []
        if spotify_tracks:
            shelves.append(ShelfSection(
                title="Хиты Spotify" if is_ru else "Spotify Top Hits",
                items=spotify_tracks
            ))
        if soundcloud_tracks:
            shelves.append(ShelfSection(
                title="SoundCloud Тренды & Phonk" if is_ru else "SoundCloud Electronic & Beats",
                items=soundcloud_tracks
            ))
        if yt_tracks:
            shelves.append(ShelfSection(
                title="Чарт YouTube Music" if is_ru else "YouTube Music Top",
                items=yt_tracks
            ))

        return FeedResponse(trending=trending, shelves=shelves)

    async def get_recommendations_for_track(self, track_id: str, limit: int = 15) -> List[TrackItem]:
        video_id = track_id.replace("yn_yt_", "").replace("yn_sc_", "").replace("yn_sp_", "")
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
                thumbs = item.get("thumbnails", [])
                artwork_url = thumbs[-1].get("url") if thumbs else None
                tid = f"yn_yt_{vid}"
                tracks.append(TrackItem(
                    id=tid,
                    title=item.get("title", "Unknown"),
                    artist=artists,
                    album=item.get("album", {}).get("name") if item.get("album") else None,
                    duration_ms=0,
                    artwork_url=artwork_url,
                    source="youtube",
                    stream_url=f"/api/v1/stream?track_id={tid}"
                ))
            return tracks
        except Exception:
            return []

feed_service = FeedService()
