from fastapi import FastAPI

from app.routers import auth

app = FastAPI(title="Receipt-Fax API", version="1.0.0")

app.include_router(auth.router, prefix="/api/v1")
