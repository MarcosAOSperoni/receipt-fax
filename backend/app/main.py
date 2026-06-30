from fastapi import FastAPI

from app.routers import auth, devices, media, messages

app = FastAPI(title="Receipt-Fax API", version="1.0.0")

app.include_router(auth.router, prefix="/api/v1")
app.include_router(devices.router, prefix="/api/v1")
app.include_router(messages.router, prefix="/api/v1")
app.include_router(media.router, prefix="/api/v1")
