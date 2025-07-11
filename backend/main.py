from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from datetime import datetime
from routers import ai_analysis, call
import os
import socketio

# Create base FastAPI app
app = FastAPI()

# Allow CORS for frontend apps
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include all API routes
app.include_router(ai_analysis.router, prefix="/ai-analysis")

# Wrap app with Socket.IO from call.py
socket_app = socketio.ASGIApp(call.sio, other_asgi_app=app)


# META_FILE = "uploads/meta.txt"
# os.makedirs("uploaded_videos", exist_ok=True)

# @app.post("/upload")
# async def upload_data(
#     video: UploadFile = File(...),
#     latitude: float = Form(...),
#     longitude: float = Form(...),
#     prompt: str = Form(...),
# ):
#     # Save video file (convert .temp to .mp4 if needed)
#     filename = video.filename
#     if filename.endswith('.temp'):
#         filename = filename.rsplit('.', 1)[0] + '.mp4'
#     save_path = f"uploaded_videos/{filename}"
#     contents = await video.read()
#     with open(save_path, "wb") as f:
#         f.write(contents)

#     # You can now use all values
#     print("📍 Location:", latitude, longitude)
#     print("📝 Prompt:", prompt)

#     return JSONResponse({
#         "status": "received",
#         "filename": filename,
#         "location": {"lat": latitude, "lon": longitude},
#         "prompt": prompt,
#     })