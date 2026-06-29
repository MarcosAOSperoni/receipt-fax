from fastapi import FastAPI

from app.routers import auth, devices

app = FastAPI(title="Receipt-Fax API", version="1.0.0")

app.include_router(auth.router, prefix="/api/v1")
app.include_router(devices.router, prefix="/api/v1")
