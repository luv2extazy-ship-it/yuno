from fastapi import APIRouter, Request, HTTPException
from app.services.stream_service import stream_service

router = APIRouter(tags=["stream"])

@router.get("/stream/{track_id}")
async def stream_audio(track_id: str, request: Request):
    if not track_id:
        raise HTTPException(status_code=400, detail="Track ID is required")
    return await stream_service.get_stream_response(track_id, request)
