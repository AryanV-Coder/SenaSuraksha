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

# Add a catch-all event handler for debugging
@sio.event
async def catch_all(event, sid, data):
    print(f"🔍 Received event '{event}' from {sid}: {data}")

@sio.on('join')
async def handle_join(sid, user_id):
    clients[user_id] = sid
    print(f"{user_id} joined with SID: {sid}")
    print(f"Current clients: {list(clients.keys())}")

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

@sio.on('call-rejected')
async def handle_call_rejected(sid, data):
    to = data.get("to")
    from_user = get_user_id_by_sid(sid)
    print(f"📢 CALL-REJECTED: {from_user} -> {to}")
    print(f"📢 Data received: {data}")
    print(f"📢 Current clients: {list(clients.keys())}")
    
    if to in clients:
        await sio.emit('call-rejected', {'from': from_user}, to=clients[to])
        print(f"✅ Call rejected forwarded successfully")
    else:
        print(f"❌ Target {to} not found in clients")

def get_user_id_by_sid(sid):
    for uid, socket_sid in clients.items():
        if socket_sid == sid:
            return uid
    return None
