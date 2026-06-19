import { Server as HttpServer } from 'http';
import { WebSocket, WebSocketServer } from 'ws';
import jwt from 'jsonwebtoken';
import url from 'url';

const JWT_SECRET = process.env.JWT_SECRET as string;
const connections = new Map<number, Set<WebSocket>>();

export function setupWebSocketServer(server: HttpServer) {
  const wss = new WebSocketServer({ noServer: true });

  server.on('upgrade', (req, socket, head) => {
    const { pathname, query } = url.parse(req.url ?? '', true);
    if (pathname !== '/ws') {
      socket.destroy();
      return;
    }

    try {
      const payload = jwt.verify(query.token as string, JWT_SECRET) as { userId: number };
      wss.handleUpgrade(req, socket, head, (ws) => {
        wss.emit('connection', ws, payload.userId);
      });
    } catch {
      socket.destroy();
    }
  });

  wss.on('connection', (ws: WebSocket, userId: number) => {
    if (!connections.has(userId)) connections.set(userId, new Set());
    connections.get(userId)!.add(ws);

    ws.on('close', () => {
      connections.get(userId)?.delete(ws);
      if (connections.get(userId)?.size === 0) connections.delete(userId);
    });
  });
}

export function sendToUser(userId: number, event: string, data: unknown) {
  const sockets = connections.get(userId);
  if (!sockets) return;
  const message = JSON.stringify({ event, data });
  for (const socket of sockets) {
    if (socket.readyState === WebSocket.OPEN) socket.send(message);
  }
}
