import express from "express";
import http from "http";
import { Server } from "socket.io";

const PORT = process.env.PORT || 3000;

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: "*" }, // tighten in production
  maxHttpBufferSize: 1e4, // 10 KB is plenty for tiny buffers
});

// Track the two roles
let bridgeSocket = null;
let controllerSocket = null;

// ── Health-check endpoint ────────────────────────────────────
app.get("/", (_req, res) => {
  res.json({
    status: "ok",
    bridge: bridgeSocket ? "connected" : "disconnected",
    controller: controllerSocket ? "connected" : "disconnected",
  });
});

// ── Socket.IO ────────────────────────────────────────────────
io.on("connection", (socket) => {
  console.log(`[+] Client connected: ${socket.id}`);

  // Each client must immediately emit 'register' with its role
  socket.on("register", (role) => {
    if (role === "bridge") {
      bridgeSocket = socket;
      console.log(`[bridge] registered: ${socket.id}`);
      // Notify controller if it's already connected
      controllerSocket?.emit("peer-joined");
    } else if (role === "controller") {
      controllerSocket = socket;
      console.log(`[controller] registered: ${socket.id}`);
      // Notify bridge if it's already connected
      bridgeSocket?.emit("peer-joined");
    }
  });

  // ── WebRTC Signaling ─────────────────────────────────────────
  // Forwards SDP offers/answers and ICE candidates between the two peers
  socket.on("signal", ({ data }) => {
    if (socket === bridgeSocket && controllerSocket?.connected) {
      controllerSocket.emit("signal", data);
    } else if (socket === controllerSocket && bridgeSocket?.connected) {
      bridgeSocket.emit("signal", data);
    }
  });

  // ── Role-based Relay ─────────────────────────────────────────

  // Controller → bridge: forward command buffer
  socket.on("cmd", (data) => {
    if (bridgeSocket && bridgeSocket.connected) {
      console.log("Data: ", data)
      bridgeSocket.emit("cmd", data);
    }
  });

  // Commands to run directly without arudino
  socket.on("direct", (data) => {
    console.log(data);
    if (bridgeSocket && bridgeSocket.connected) {
      bridgeSocket.emit("direct", data);
    }
  });

  // Controller → bridge: forward camera switch requests
  socket.on("camera-switch", (data) => {
    if (socket === controllerSocket && bridgeSocket && bridgeSocket.connected) {
      console.log("Data: ", data);
      bridgeSocket.emit("camera-switch", data);
    }
  });

  // Bridge → controller: forward telemetry buffer
  socket.on("telem", (data) => {
    // console.log(data)
    if (controllerSocket && controllerSocket.connected) {
      controllerSocket.emit("telem", data);
    }
  });

  // ── Cleanup ──────────────────────────────────────────────────
  socket.on("disconnect", () => {
    if (socket === bridgeSocket) {
      bridgeSocket = null;
      controllerSocket?.emit("peer-disconnected");
      console.log(`[-] Bridge disconnected: ${socket.id}`);
    } else if (socket === controllerSocket) {
      controllerSocket = null;
      bridgeSocket?.emit("peer-disconnected");
      console.log(`[-] Controller disconnected: ${socket.id}`);
    } else {
      console.log(`[-] Unknown client disconnected: ${socket.id}`);
    }
  });
});

// ── Start ────────────────────────────────────────────────────
server.listen(PORT, () => {
  console.log(`RC relay server listening on port ${PORT}`);
});
