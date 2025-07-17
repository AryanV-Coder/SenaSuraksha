const micBtn = document.getElementById('micBtn');
const endBtn = document.getElementById('endBtn');
const statusText = document.getElementById('status');

let socket = null; // Don't connect immediately
const selfId = "commander";  // Unique per user; you can make this dynamic
let targetId = null;

let localStream;
let peerConnection;

micBtn.onclick = async () => {
  statusText.textContent = "Connecting to signaling server...";
  await connectToSignalingServer();
  await startCall();
};

endBtn.onclick = async () => {
  endCall();
};

async function connectToSignalingServer() {
  if (socket && socket.connected) {
    return; // Already connected
  }

  socket = io("https://senasuraksha.onrender.com", {
    transports: ["websocket"]
  });

  return new Promise((resolve) => {
    socket.on("connect", () => {
      console.log("Connected to signaling server");
      socket.emit("join", selfId);
      statusText.textContent = "Connected! Starting call...";
      resolve();
    });

    // Set up all socket event listeners here
    setupSocketListeners();
  });
}

function setupSocketListeners() {

socket.on("offer", async (data) => {
  targetId = data.from;
  await answerCall(data.offer);
});

socket.on("answer", async (data) => {
  const remoteDesc = new RTCSessionDescription(data.answer);
  await peerConnection.setRemoteDescription(remoteDesc);
  statusText.textContent = "✅ Call Connected";
  endBtn.style.display = "inline";
  micBtn.style.display = "none";
});

socket.on("ice-candidate", async (data) => {
  try {
    await peerConnection.addIceCandidate(new RTCIceCandidate(data.candidate));
  } catch (e) {
    console.error("Error adding ice candidate", e);
  }
});

socket.on("end-call", () => {
  endCall();
});

}

async function startCall() {
  targetId = "soldier1"; // Should match the peer's selfId

  await createPeerConnection();

  const offer = await peerConnection.createOffer();
  await peerConnection.setLocalDescription(offer);

  socket.emit("offer", {
    offer: offer,
    to: targetId  // ✅ this was missing
  });
}


async function answerCall(offer) {
  await createPeerConnection();

  await peerConnection.setRemoteDescription(new RTCSessionDescription(offer));

  const answer = await peerConnection.createAnswer();
  await peerConnection.setLocalDescription(answer);

  socket.emit("answer", {
    answer: answer,
    to: targetId,
  });

  statusText.textContent = "✅ Call Connected";
  endBtn.style.display = "inline";
  micBtn.style.display = "none";
}

async function createPeerConnection() {
  peerConnection = new RTCPeerConnection({
    iceServers: [{ urls: "stun:stun.l.google.com:19302" }]
  });

  localStream = await navigator.mediaDevices.getUserMedia({ audio: true });
  localStream.getTracks().forEach(track => {
    peerConnection.addTrack(track, localStream);
  });

  peerConnection.onicecandidate = (event) => {
    if (event.candidate && targetId) {
      socket.emit("ice-candidate", {
        candidate: event.candidate,
        to: targetId
      });
    }
  };

  peerConnection.onconnectionstatechange = () => {
    console.log("State:", peerConnection.connectionState);
  };
}

function endCall() {
  localStream?.getTracks().forEach(track => track.stop());
  peerConnection?.close();
  peerConnection = null;

  if (socket && targetId) {
    socket.emit("end-call", { to: targetId });
  }

  // Disconnect socket when call ends
  if (socket) {
    socket.disconnect();
    socket = null;
  }

  statusText.textContent = "❌ Call Ended";
  endBtn.style.display = "none";
  micBtn.style.display = "inline";
}
