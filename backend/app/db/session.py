from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import declarative_base
from app.core.config import settings

engine = create_async_engine(
    settings.get_database_url(),
    echo=False,
    future=True
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False
)

Base = declarative_base()

async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

from sqlalchemy import text

async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        # Safe migration if table exists in PostgreSQL with naive timestamps
        db_url = settings.get_database_url()
        if "postgres" in db_url:
            for query in [
                "ALTER TABLE users ALTER COLUMN created_at TYPE TIMESTAMP WITH TIME ZONE;",
                "ALTER TABLE playlists ALTER COLUMN created_at TYPE TIMESTAMP WITH TIME ZONE;",
                "ALTER TABLE playlists ALTER COLUMN updated_at TYPE TIMESTAMP WITH TIME ZONE;",
                "ALTER TABLE favorites ALTER COLUMN created_at TYPE TIMESTAMP WITH TIME ZONE;",
                "ALTER TABLE history ALTER COLUMN played_at TYPE TIMESTAMP WITH TIME ZONE;",
            ]:
                try:
                    await conn.execute(text(query))
                except Exception:
                    pass
