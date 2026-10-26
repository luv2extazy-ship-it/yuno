from typing import Optional
from fastapi import APIRouter, Query
from app.services.lyrics_service import fetch_lyrics, LyricsResponse

router = APIRouter(tags=["lyrics"])

@router.get("/lyrics", response_model=LyricsResponse)
async def get_lyrics(
    title: str = Query(...),
    artist: str = Query(...),
    album: Optional[str] = Query(None),
    duration_s: Optional[int] = Query(None)
):
    return await fetch_lyrics(title=title, artist=artist, album=album, duration_s=duration_s)
