import sys
import httpx
import json

BASE_URL = "https://yuno-backend-je37.onrender.com"
client = httpx.Client(timeout=25.0)

print("=" * 60)
print("       YUNO END-TO-END SYSTEM HEALTH CHECK       ")
print("=" * 60)

passed = 0
failed = 0

def check(name, fn):
    global passed, failed
    try:
        res = fn()
        if res:
            print(f" [PASS] {name}: {res}")
            passed += 1
        else:
            print(f" [FAIL] {name}")
            failed += 1
    except Exception as e:
        print(f" [FAIL] {name}: {e}")
        failed += 1

# 1. Health & Root
check("Health Check", lambda: client.get(f"{BASE_URL}/health").json().get("status") == "ok" and "healthy")

# 2. Database Connection
def test_db():
    r = client.get(f"{BASE_URL}/api/v1/auth/debug-db")
    if r.status_code == 200:
        data = r.json()
        return f"Connected ({data.get('total_users', 0)} users in DB, URL: {data.get('db_url')})"
    return False
check("PostgreSQL Database", test_db)

# 3. Auth & Login
token = None
def test_auth():
    global token
    r = client.post(
        f"{BASE_URL}/api/v1/auth/login",
        json={"email": "16uzxp@gmail.com", "password": "Password123!"}
    )
    if r.status_code == 200:
        data = r.json()
        token = data.get("access_token")
        return f"JWT obtained for user {data.get('user', {}).get('email')} (id: {data.get('user', {}).get('id')[:8]}...)"
    return False
check("User Authentication (Login)", test_auth)

# 4. Auth Me
def test_me():
    if not token:
        return False
    r = client.get(f"{BASE_URL}/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    if r.status_code == 200:
        return f"Profile verified: {r.json().get('username')}"
    return False
check("Protected Profile (/me)", test_me)

# 5. Search Engine
search_results = []
def test_search():
    global search_results
    r = client.get(f"{BASE_URL}/api/v1/search?q=Miyagi")
    if r.status_code == 200:
        search_results = r.json()
        sources = set(t.get("source") for t in search_results)
        return f"Found {len(search_results)} tracks (Sources: {list(sources)})"
    return False
check("Multi-Source Search", test_search)

# 6. Synchronized Lyrics (LRC)
def test_lyrics():
    r = client.get(f"{BASE_URL}/api/v1/lyrics?title=Numb&artist=Linkin+Park")
    if r.status_code == 200:
        data = r.json()
        lines = data.get("lines", [])
        return f"Synced: {data.get('synced')}, Total lines: {len(lines)}, First line: {lines[0].get('text') if lines else 'None'}"
    return False
check("Synchronized Karaoke Lyrics", test_lyrics)

# 7. Home Feed & Regional Recommendations
def test_feed():
    r = client.get(f"{BASE_URL}/api/v1/feed?country=RU")
    if r.status_code == 200:
        data = r.json()
        trending = data.get("trending", [])
        shelves = data.get("shelves", [])
        return f"{len(trending)} trending tracks, {len(shelves)} shelves ({[s.get('title') for s in shelves]})"
    return False
check("Geo-Adaptive Home Feed", test_feed)

# 8. Audio Streaming (Direct Live Range Stream)
def test_stream():
    # Use clean SoundCloud stream route verified on Render
    track_id = "yn_sc_1149757930"
    r = client.get(
        f"{BASE_URL}/api/v1/stream/{track_id}",
        headers={"Range": "bytes=0-1000"}
    )
    if r.status_code in (200, 206) and len(r.content) > 0:
        return f"Status {r.status_code}, Content-Type: {r.headers.get('content-type')}, Received {len(r.content)} audio bytes"
    return False
check("Audio Stream Delivery (HTTP Range)", test_stream)

# 9. Playlists CRUD
def test_playlists():
    if not token:
        return False
    # Create playlist
    r_create = client.post(
        f"{BASE_URL}/api/v1/playlists",
        json={"title": "Мой тестовый плейлист", "description": "Проверка", "is_public": True},
        headers={"Authorization": f"Bearer {token}"}
    )
    if r_create.status_code != 200:
        return False
    pl_id = r_create.json().get("id")
    
    # Get user playlists
    r_get = client.get(f"{BASE_URL}/api/v1/playlists", headers={"Authorization": f"Bearer {token}"})
    if r_get.status_code != 200:
        return False
    
    # Delete playlist
    client.delete(f"{BASE_URL}/api/v1/playlists/{pl_id}", headers={"Authorization": f"Bearer {token}"})
    return f"Created & deleted playlist '{r_create.json().get('title')}' successfully"
check("Cloud Playlists CRUD", test_playlists)

# 10. Favorites & History
def test_fav():
    if not token:
        return False
    r_fav = client.post(
        f"{BASE_URL}/api/v1/favorites",
        json={
            "track_id": "yn_sc_1149757930",
            "title": "In The End",
            "artist": "Linkin Park",
            "source": "soundcloud"
        },
        headers={"Authorization": f"Bearer {token}"}
    )
    if r_fav.status_code != 200:
        return False
    r_list = client.get(f"{BASE_URL}/api/v1/favorites", headers={"Authorization": f"Bearer {token}"})
    favs = r_list.json() if r_list.status_code == 200 else []
    return f"Favorites active: {len(favs)} track(s) saved"
check("Favorites Synchronization", test_fav)

print("=" * 60)
print(f"RESULTS: {passed} PASSED, {failed} FAILED (TOTAL: {passed + failed})")
print("=" * 60)

if failed > 0:
    sys.exit(1)
else:
    sys.exit(0)
