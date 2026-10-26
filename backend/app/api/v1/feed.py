from typing import List
from fastapi import APIRouter
from app.services.feed_service import feed_service, FeedResponse
from app.services.search_service import TrackItem

router = APIRouter(tags=["feed"])

@router.get("/feed", response_model=FeedResponse)
async def get_feed():
    return await feed_service.get_home_feed()

@router.get("/radio/{track_id}", response_model=List[TrackItem])
async def get_radio(track_id: str):
    return await feed_service.get_recommendations_for_track(track_id)
