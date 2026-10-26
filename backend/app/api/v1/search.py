from typing import List
from fastapi import APIRouter, Query
from app.services.search_service import search_service, TrackItem

router = APIRouter(tags=["search"])

@router.get("/search", response_model=List[TrackItem])
async def search(q: str = Query(..., min_length=1), limit: int = Query(15, ge=1, le=50)):
    return await search_service.search_all(query=q, limit_per_source=limit)
