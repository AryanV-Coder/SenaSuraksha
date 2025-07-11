import socketio

sio = socketio.AsyncServer(async_mode='asgi', cors_allowed_origins='*')

clients = {}  # user_id -> sid

@sio.event
async def connect(sid, environ):
    print(f"Client connected: {sid}")

@sio.event
async def disconnect(sid):
    print(f"Client disconnected: {sid}")
    for uid, socket_sid in list(clients.items()):
        if socket_sid == sid:
            del clients[uid]
            break

@sio.on('join')
async def handle_join(sid, user_id):
    clients[user_id] = sid
    print(f"{user_id} joined with SID: {sid}")

@sio.on('offer')
async def handle_offer(sid, data):
    to = data.get("to")
    offer = data.get("offer")
    if to in clients:
        await sio.emit('offer', {'offer': offer, 'from': get_user_id_by_sid(sid)}, to=clients[to])

@sio.on('answer')
async def handle_answer(sid, data):
    to = data.get("to")
    answer = data.get("answer")
    if to in clients:
        await sio.emit('answer', {'answer': answer, 'from': get_user_id_by_sid(sid)}, to=clients[to])

@sio.on('ice-candidate')
async def handle_ice_candidate(sid, data):
    to = data.get("to")
    candidate = data.get("candidate")
    if to in clients:
        await sio.emit('ice-candidate', {'candidate': candidate, 'from': get_user_id_by_sid(sid)}, to=clients[to])

@sio.on('end-call')
async def handle_end_call(sid, data):
    to = data.get("to")
    if to in clients:
        await sio.emit('end-call', {'from': get_user_id_by_sid(sid)}, to=clients[to])

def get_user_id_by_sid(sid):
    for uid, socket_sid in clients.items():
        if socket_sid == sid:
            return uid
    return None
