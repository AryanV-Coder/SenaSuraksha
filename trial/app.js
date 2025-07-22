const micBtn = document.getElementById('micBtn');
const endBtn = document.getElementById('endBtn');
const statusText = document.getElementById('status');

let socket = null; // Don't connect immediately
const selfId = "commander";  // Unique per user; you can make this dynamic
let targetId = null;

let localStream;
let peerConnection;

// Register immediately when page loads so user can receive calls
window.addEventListener('DOMContentLoaded', async () => {
  statusText.textContent = "Registering for incoming calls...";
  await connectToSignalingServer();
  statusText.textContent = "Ready to receive calls";
});

micBtn.onclick = async () => {
  statusText.textContent = "Starting call...";
  await connectToSignalingServer(); // Ensure connected
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
    // Don't overwrite status if we're starting a call
    if (!statusText.textContent.includes("Starting call")) {
      statusText.textContent = "Ready to receive calls";
    }
    resolve();
  });

    // Set up all socket event listeners here
    setupSocketListeners();
  });
}

function setupSocketListeners() {

socket.on("offer", async (data) => {
  targetId = data.from;
  
  // Show incoming call popup
  const acceptCall = confirm("📞 Incoming call! Accept?");
  if (acceptCall) {
    statusText.textContent = "Accepting call...";
    await answerCall(data.offer);
  } else {
    console.log("Rejecting call from:", targetId);
    // Optionally notify rejection
    socket.emit("call-rejected", { to: targetId });
    console.log("Sent call-rejected to:", targetId);
    targetId = null;
  }
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

socket.on("call-rejected", () => {
  console.log("Call was rejected by remote user");
  statusText.textContent = "Call rejected - Ready to receive calls";
  endBtn.style.display = "none";
  micBtn.style.display = "inline";
  
  // Clean up any existing connection
  if (localStream) {
    localStream.getTracks().forEach(track => track.stop());
    localStream = null;
  }
  if (peerConnection) {
    peerConnection.close();
    peerConnection = null;
  }
  targetId = null;
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

  // Handle incoming audio stream
  peerConnection.ontrack = (event) => {
    console.log("Received remote stream");
    const remoteAudio = document.getElementById('remoteAudio') || createAudioElement();
    remoteAudio.srcObject = event.streams[0];
    remoteAudio.play().catch(e => console.log("Audio play failed:", e));
  };

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

function createAudioElement() {
  const audio = document.createElement('audio');
  audio.id = 'remoteAudio';
  audio.autoplay = true;
  audio.controls = false;
  document.body.appendChild(audio);
  return audio;
}

function endCall() {
  localStream?.getTracks().forEach(track => track.stop());
  peerConnection?.close();
  peerConnection = null;

  if (socket && targetId) {
    socket.emit("end-call", { to: targetId });
  }

  // DON'T disconnect socket - keep registered for incoming calls
  targetId = null;

  statusText.textContent = "❌ Call Ended - Ready to receive calls";
  endBtn.style.display = "none";
  micBtn.style.display = "inline";
}
