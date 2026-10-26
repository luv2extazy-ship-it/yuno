from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from sqlalchemy.orm import selectinload
from pydantic import BaseModel
from datetime import datetime, timezone

from app.db.session import get_db
from app.db.models import User, Playlist, PlaylistTrack, Favorite, History
from app.api.v1.auth import get_current_user

router = APIRouter(tags=["library"])

# Schemas
class TrackPayload(BaseModel):
    track_id: str
    title: str
    artist: str
    album: Optional[str] = None
    duration_ms: int = 0
    artwork_url: Optional[str] = None
    source: str = "unknown"

class PlaylistCreate(BaseModel):
    title: str
    description: Optional[str] = None
    cover_url: Optional[str] = None
    is_public: bool = True

class PlaylistTrackResponse(BaseModel):
    id: str
    track_id: str
    title: str
    artist: str
    album: Optional[str]
    duration_ms: int
    artwork_url: Optional[str]
    source: str
    position: int

class PlaylistResponse(BaseModel):
    id: str
    title: str
    description: Optional[str]
    cover_url: Optional[str]
    is_public: bool
    user_id: str
    tracks: List[PlaylistTrackResponse] = []

# --- PLAYLISTS ---

@router.get("/playlists", response_model=List[PlaylistResponse])
async def get_my_playlists(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = (
        select(Playlist)
        .where(Playlist.user_id == user.id)
        .options(selectinload(Playlist.tracks))
        .order_by(Playlist.created_at.desc())
    )
    res = await db.execute(stmt)
    playlists = res.scalars().all()
    return playlists

@router.post("/playlists", response_model=PlaylistResponse)
async def create_playlist(req: PlaylistCreate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    pl = Playlist(
        user_id=user.id,
        title=req.title,
        description=req.description,
        cover_url=req.cover_url,
        is_public=req.is_public
    )
    db.add(pl)
    await db.commit()
    # Query with eager load
    stmt = select(Playlist).where(Playlist.id == pl.id).options(selectinload(Playlist.tracks))
    res = await db.execute(stmt)
    return res.scalar_one()

@router.get("/playlists/{playlist_id}", response_model=PlaylistResponse)
async def get_playlist(playlist_id: str, db: AsyncSession = Depends(get_db)):
    stmt = select(Playlist).where(Playlist.id == playlist_id).options(selectinload(Playlist.tracks))
    res = await db.execute(stmt)
    pl = res.scalar_one_or_none()
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")
    return pl

@router.post("/playlists/{playlist_id}/tracks", response_model=PlaylistTrackResponse)
async def add_track_to_playlist(
    playlist_id: str,
    req: TrackPayload,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Playlist).where(Playlist.id == playlist_id, Playlist.user_id == user.id)
    res = await db.execute(stmt)
    pl = res.scalar_one_or_none()
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found or access denied")

    track = PlaylistTrack(
        playlist_id=playlist_id,
        track_id=req.track_id,
        title=req.title,
        artist=req.artist,
        album=req.album,
        duration_ms=req.duration_ms,
        artwork_url=req.artwork_url,
        source=req.source
    )
    db.add(track)
    await db.commit()
    await db.refresh(track)
    return track

@router.delete("/playlists/{playlist_id}/tracks/{track_id}")
async def remove_track_from_playlist(
    playlist_id: str,
    track_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Playlist).where(Playlist.id == playlist_id, Playlist.user_id == user.id)
    res = await db.execute(stmt)
    if not res.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Playlist not found or access denied")

    del_stmt = delete(PlaylistTrack).where(
        PlaylistTrack.playlist_id == playlist_id,
        PlaylistTrack.track_id == track_id
    )
    await db.execute(del_stmt)
    await db.commit()
    return {"status": "ok", "message": "Track removed from playlist"}

# --- FAVORITES ---

@router.get("/favorites", response_model=List[TrackPayload])
async def get_favorites(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = select(Favorite).where(Favorite.user_id == user.id).order_by(Favorite.created_at.desc())
    res = await db.execute(stmt)
    favorites = res.scalars().all()
    return [
        TrackPayload(
            track_id=f.track_id,
            title=f.title,
            artist=f.artist,
            album=f.album,
            duration_ms=f.duration_ms,
            artwork_url=f.artwork_url,
            source=f.source
        )
        for f in favorites
    ]

@router.post("/favorites")
async def toggle_favorite(req: TrackPayload, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = select(Favorite).where(Favorite.user_id == user.id, Favorite.track_id == req.track_id)
    res = await db.execute(stmt)
    existing = res.scalar_one_or_none()

    if existing:
        await db.delete(existing)
        await db.commit()
        return {"status": "removed", "is_favorite": False}
    else:
        fav = Favorite(
            user_id=user.id,
            track_id=req.track_id,
            title=req.title,
            artist=req.artist,
            album=req.album,
            duration_ms=req.duration_ms,
            artwork_url=req.artwork_url,
            source=req.source
        )
        db.add(fav)
        await db.commit()
        return {"status": "added", "is_favorite": True}

# --- HISTORY ---

@router.post("/history")
async def record_history(req: TrackPayload, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    hist = History(
        user_id=user.id,
        track_id=req.track_id,
        title=req.title,
        artist=req.artist,
        album=req.album,
        duration_ms=req.duration_ms,
        artwork_url=req.artwork_url,
        source=req.source,
        played_at=datetime.now(timezone.utc)
    )
    db.add(hist)
    await db.commit()
    return {"status": "ok"}

@router.get("/history", response_model=List[TrackPayload])
async def get_history(limit: int = 20, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    stmt = select(History).where(History.user_id == user.id).order_by(History.played_at.desc()).limit(limit)
    res = await db.execute(stmt)
    records = res.scalars().all()
    return [
        TrackPayload(
            track_id=h.track_id,
            title=h.title,
            artist=h.artist,
            album=h.album,
            duration_ms=h.duration_ms,
            artwork_url=h.artwork_url,
            source=h.source
        )
        for h in records
    ]
