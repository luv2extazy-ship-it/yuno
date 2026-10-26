import re
import httpx
from typing import Optional, List, Tuple
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

def clean_metadata(title: str, artist: str) -> Tuple[str, str]:
    clean_title = title
    clean_artist = artist
    if " - " in title:
        parts = title.split(" - ", 1)
        if len(parts) == 2:
            pot_artist, pot_title = parts[0].strip(), parts[1].strip()
            if artist.lower() in ("unknown", "top chart", "top hits", "soundcloud", "") or pot_artist.lower() in artist.lower():
                clean_artist = pot_artist
                clean_title = pot_title
            else:
                clean_title = pot_title

    noise_patterns = [
        r"(?i)\s*[\(\[\{]official\s*(music\s*)?(video|audio|visualizer|lyric video)?[\)\]\}]",
        r"(?i)\s*[\(\[\{](audio|lyrics|lyric video|visualizer|remastered|hd|4k)[\)\]\}]",
        r"(?i)\s*[\(\[\{]live(\s+from\s+[^)\]}]+)?[\)\]\}]",
        r"(?i)\s*(feat\.?|ft\.?)\s+[^(\[\-]+",
    ]
    for pat in noise_patterns:
        clean_title = re.sub(pat, "", clean_title).strip()
        clean_artist = re.sub(pat, "", clean_artist).strip()

    clean_title = re.sub(r'["\']', '', clean_title).strip()
    clean_artist = re.sub(r'["\']', '', clean_artist).strip()
    return clean_title or title, clean_artist or artist

async def fetch_lyrics(title: str, artist: str, album: Optional[str] = None, duration_s: Optional[int] = None) -> LyricsResponse:
    clean_t, clean_a = clean_metadata(title, artist)
    headers = {"User-Agent": "YunoMusicApp/1.0.0"}

    async with httpx.AsyncClient(timeout=6.0, follow_redirects=True) as client:
        # 1. Try exact match with cleaned title & artist
        url = "https://lrclib.net/api/get"
        params = {
            "track_name": clean_t,
            "artist_name": clean_a,
        }
        if album:
            params["album_name"] = album
        if duration_s:
            params["duration"] = str(duration_s)

        try:
            resp = await client.get(url, params=params, headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                synced_lyrics = data.get("syncedLyrics")
                plain_lyrics = data.get("plainLyrics")
                if synced_lyrics:
                    return LyricsResponse(
                        track_name=title,
                        artist_name=artist,
                        synced=True,
                        plain_lyrics=plain_lyrics,
                        lines=parse_lrc(synced_lyrics)
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

        # 2. Fallback: Search with cleaned artist & title
        search_queries = [
            f"{clean_a} {clean_t}".strip(),
            clean_t.strip(),
            f"{artist} {title}".strip()
        ]

        for q in search_queries:
            if not q:
                continue
            try:
                search_url = "https://lrclib.net/api/search"
                search_resp = await client.get(search_url, params={"q": q}, headers=headers)
                if search_resp.status_code == 200:
                    results = search_resp.json()
                    if results and isinstance(results, list):
                        synced_item = next((r for r in results if r.get("syncedLyrics")), None)
                        item = synced_item or results[0]
                        synced_text = item.get("syncedLyrics")
                        plain_text = item.get("plainLyrics")
                        
                        if synced_text:
                            return LyricsResponse(
                                track_name=title,
                                artist_name=artist,
                                synced=True,
                                plain_lyrics=plain_text,
                                lines=parse_lrc(synced_text)
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
