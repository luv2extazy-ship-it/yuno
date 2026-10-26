import re
import httpx
from typing import Optional, List
from pydantic import BaseModel

class LyricLine(BaseModel):
    timestamp_ms: int
    time_tag: str
    text: str

class LyricsResponse(BaseModel):
    track_name: str
    artist_name: str
    synced: bool
    plain_lyrics: Optional[str] = None
    lines: List[LyricLine] = []

def parse_lrc(lrc_text: str) -> List[LyricLine]:
    lines: List[LyricLine] = []
    if not lrc_text:
        return lines

    pattern = re.compile(r"\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)")
    for raw_line in lrc_text.splitlines():
        match = pattern.match(raw_line.strip())
        if match:
            minutes = int(match.group(1))
            seconds = int(match.group(2))
            millis_str = match.group(3)
            # Normalize 2-digit millis (.42 -> 420ms) or 3-digit (.420 -> 420ms)
            if len(millis_str) == 2:
                millis = int(millis_str) * 10
            else:
                millis = int(millis_str[:3])
            
            timestamp_ms = (minutes * 60 + seconds) * 1000 + millis
            text = match.group(4).strip()
            lines.append(LyricLine(
                timestamp_ms=timestamp_ms,
                time_tag=f"[{match.group(1)}:{match.group(2)}.{millis_str}]",
                text=text
            ))
    lines.sort(key=lambda x: x.timestamp_ms)
    return lines

async def fetch_lyrics(title: str, artist: str, album: Optional[str] = None, duration_s: Optional[int] = None) -> LyricsResponse:
    # 1. Try exact match from LRCLIB
    url = "https://lrclib.net/api/get"
    params = {
        "track_name": title,
        "artist_name": artist,
    }
    if album:
        params["album_name"] = album
    if duration_s:
        params["duration"] = str(duration_s)

    async with httpx.AsyncClient(timeout=6.0, follow_redirects=True) as client:
        try:
            resp = await client.get(url, params=params, headers={"User-Agent": "YunoMusicApp/1.0.0"})
            if resp.status_code == 200:
                data = resp.json()
                synced_lyrics = data.get("syncedLyrics")
                plain_lyrics = data.get("plainLyrics")
                
                if synced_lyrics:
                    lines = parse_lrc(synced_lyrics)
                    return LyricsResponse(
                        track_name=title,
                        artist_name=artist,
                        synced=True,
                        plain_lyrics=plain_lyrics,
                        lines=lines
                    )
                elif plain_lyrics:
                    return LyricsResponse(
                        track_name=title,
                        artist_name=artist,
                        synced=False,
                        plain_lyrics=plain_lyrics,
                        lines=[]
                    )
        except Exception:
            pass

        # 2. Fallback: Search LRCLIB
        try:
            search_url = "https://lrclib.net/api/search"
            q = f"{artist} {title}"
            search_resp = await client.get(search_url, params={"q": q}, headers={"User-Agent": "YunoMusicApp/1.0.0"})
            if search_resp.status_code == 200:
                results = search_resp.json()
                if results and isinstance(results, list):
                    # Pick first with synced lyrics, or first with plain lyrics
                    synced_item = next((r for r in results if r.get("syncedLyrics")), None)
                    item = synced_item or results[0]
                    
                    synced_text = item.get("syncedLyrics")
                    plain_text = item.get("plainLyrics")
                    
                    if synced_text:
                        lines = parse_lrc(synced_text)
                        return LyricsResponse(
                            track_name=title,
                            artist_name=artist,
                            synced=True,
                            plain_lyrics=plain_text,
                            lines=lines
                        )
                    elif plain_text:
                        return LyricsResponse(
                            track_name=title,
                            artist_name=artist,
                            synced=False,
                            plain_lyrics=plain_text,
                            lines=[]
                        )
        except Exception:
            pass

    return LyricsResponse(
        track_name=title,
        artist_name=artist,
        synced=False,
        plain_lyrics="Текст песни не найден",
        lines=[]
    )
