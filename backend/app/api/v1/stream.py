from typing import Optional
from fastapi import APIRouter, Request, HTTPException, Query
from app.services.stream_service import stream_service

router = APIRouter(tags=["stream"])

@router.get("/stream")
async def stream_audio_query(request: Request, track_id: Optional[str] = Query(None), id: Optional[str] = Query(None)):
    target_id = track_id or id
    if not target_id:
        raise HTTPException(status_code=400, detail="Track ID is required")
    return await stream_service.get_stream_response(target_id, request)

@router.get("/stream/{track_id:path}")
async def stream_audio_path(track_id: str, request: Request):
    if not track_id:
        raise HTTPException(status_code=400, detail="Track ID is required")
    return await stream_service.get_stream_response(track_id, request)
