import asyncio
import httpx
from app.db.session import init_db, AsyncSessionLocal
from app.services.lyrics_service import fetch_lyrics
from app.services.search_service import search_service
from app.services.stream_service import stream_service
from app.core.security import hash_password, verify_password, create_access_token, decode_access_token
from app.db.models import User, Playlist, PlaylistTrack, Favorite

async def run_tests():
    print("========================================")
    print("   YUNO BACKEND VERIFICATION SUITE      ")
    print("========================================")

    # 1. DB Initialization
    print("\n[1/5] Initializing SQLite database...")
    await init_db()
    print(" -> SUCCESS: Database schema ready.")

    # 2. Auth & JWT Verification
    print("\n[2/5] Testing Auth, Password Hashing & JWT...")
    raw_pass = "SecurePass2026!"
    hashed = hash_password(raw_pass)
    assert verify_password(raw_pass, hashed) is True, "Password verification failed"
    assert verify_password("WrongPassword", hashed) is False, "False positive in password check"

    token = create_access_token("test-user-id-123")
    decoded_id = decode_access_token(token)
    assert decoded_id == "test-user-id-123", "JWT decoding failed"
    print(" -> SUCCESS: Password hashing and JWT generation/validation passed.")

    # 3. Synchronized Karaoke Lyrics
    print("\n[3/5] Testing Synchronized Karaoke Lyrics (LRCLIB)...")
    lyrics_res = await fetch_lyrics(title="In the End", artist="Linkin Park")
    print(f" -> Track: {lyrics_res.track_name} - {lyrics_res.artist_name}")
    print(f" -> Synced: {lyrics_res.synced}, Total lines: {len(lyrics_res.lines)}")
    assert lyrics_res.synced is True, "Expected synchronized lyrics"
    assert len(lyrics_res.lines) > 20, "Expected full lyrics lines"
    sample = lyrics_res.lines[0]
    print(f" -> Sample lyric line: {sample.time_tag} '{sample.text}' ({sample.timestamp_ms}ms)")
    print(" -> SUCCESS: LRC parser and LRCLIB integration verified.")

    # 4. Search Aggregator
    print("\n[4/5] Testing Search Service...")
    tracks = await search_service.search_all("Dua Lipa", limit_per_source=3)
    print(f" -> Found {len(tracks)} tracks:")
    for t in tracks:
        print(f"    - [{t.source.upper()}] {t.artist} - {t.title}")
    assert len(tracks) > 0, "Search returned 0 tracks"
    print(" -> SUCCESS: Search engine returned valid tracks.")

    # 5. Stream Extraction
    print("\n[5/5] Testing Audio Stream Extraction via yt-dlp...")
    sample_track = tracks[0]
    print(f" -> Resolving audio stream for: {sample_track.title} ({sample_track.id})...")
    loop = asyncio.get_event_loop()
    stream_url, duration = await loop.run_in_executor(None, stream_service.get_source_url, sample_track.id)
    print(f" -> Direct Stream URL: {stream_url[:65]}...")
    print(f" -> Duration: {duration}s")
    assert stream_url.startswith("http"), "Invalid audio stream URL"
    print(" -> SUCCESS: Direct audio stream extracted.")

    print("\n========================================")
    print(" ALL 5 BACKEND VERIFICATIONS COMPLETED! ")
    print("========================================")

if __name__ == "__main__":
    asyncio.run(run_tests())
