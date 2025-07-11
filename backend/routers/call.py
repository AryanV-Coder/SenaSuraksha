from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Dict
from starlette.websockets import WebSocketState

router = APIRouter()

# Store connected clients (user_id: websocket)
clients: Dict[str, WebSocket] = {}

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    user_id = None

    try:
        while True:
            data = await websocket.receive_json()

            action = data.get("action")
            message = data.get("message")

            if action == "join":
                user_id = message
                clients[user_id] = websocket
                print(f"{user_id} joined")

            elif action == "offer":
                to = message.get("to")
                offer = message.get("offer")
                if to in clients and clients[to].application_state == WebSocketState.CONNECTED:
                    await clients[to].send_json({"type": "offer", "from": user_id, "offer": offer})

            elif action == "answer":
                to = message.get("to")
                answer = message.get("answer")
                if to in clients and clients[to].application_state == WebSocketState.CONNECTED:
                    await clients[to].send_json({"type": "answer", "from": user_id, "answer": answer})

            elif action == "ice-candidate":
                to = message.get("to")
                candidate = message.get("candidate")
                if to in clients and clients[to].application_state == WebSocketState.CONNECTED:
                    await clients[to].send_json({"type": "ice-candidate", "from": user_id, "candidate": candidate})

            elif action == "end-call":
                to = message.get("to")
                if to in clients and clients[to].application_state == WebSocketState.CONNECTED:
                    await clients[to].send_json({"type": "end-call", "from": user_id})

    except WebSocketDisconnect:
        print(f"{user_id} disconnected")
        if user_id in clients:
            del clients[user_id]