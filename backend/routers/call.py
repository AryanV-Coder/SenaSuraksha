from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict
import json
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

router = APIRouter()

# Dictionary to hold connected users: {user_id: websocket}
connected_users: Dict[str, WebSocket] = {}

@router.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    retry_attempts = 3
    for attempt in range(retry_attempts):
        try:
            await websocket.accept()
            connected_users[user_id] = websocket
            logger.info(f"User {user_id} connected")
            break
        except Exception as e:
            logger.error(f"Error accepting WebSocket for {user_id} (attempt {attempt+1}): {e}")
            if attempt == retry_attempts - 1:
                return

    try:
        while True:
            try:
                message = await websocket.receive_text()
                data = json.loads(message)

                # Extract details
                to_user = data.get("to")
                payload = data.get("data")  # This could be SDP, ICE, call type, etc.
                call_type = data.get("call_type")  # Optional: "commander_call" or "soldier_call"

                # Relay to intended user if connected
                if to_user in connected_users:
                    await connected_users[to_user].send_text(json.dumps({
                        "from": user_id,
                        "data": payload,
                        "call_type": call_type
                    }))
                    logger.info(f"Relayed message from {user_id} to {to_user} ({call_type})")
                else:
                    logger.warning(f"Target user {to_user} not connected")
                    await websocket.send_text(json.dumps({"error": f"User {to_user} not connected"}))

            except Exception as e:
                logger.error(f"Error during message relay for {user_id}: {e}")
                break
    except WebSocketDisconnect:
        logger.info(f"User {user_id} disconnected")
    finally:
        if user_id in connected_users:
            del connected_users[user_id]
            logger.info(f"User {user_id} removed from connected_users")
