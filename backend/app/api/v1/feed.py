from typing import List, Optional
from fastapi import APIRouter, Query
from app.services.feed_service import feed_service, FeedResponse
from app.services.search_service import TrackItem

router = APIRouter(tags=["feed"])

@router.get("/feed", response_model=FeedResponse)
async def get_feed(
    country: Optional[str] = Query("RU"),
    lang: Optional[str] = Query("ru")
):
    return await feed_service.get_home_feed(country=country or "RU", lang=lang or "ru")

@router.get("/radio/{track_id}", response_model=List[TrackItem])
async def get_radio(track_id: str):
    return await feed_service.get_recommendations_for_track(track_id)
