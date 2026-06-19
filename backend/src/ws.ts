import { Server as HttpServer } from 'http';
import { WebSocket, WebSocketServer } from 'ws';
import jwt from 'jsonwebtoken';
import url from 'url';
import { pool } from './db';

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

    ws.on('message', async (raw) => {
      let payload: { event?: string; data?: { matchId?: number } };
      try {
        payload = JSON.parse(raw.toString());
      } catch {
        return;
      }
      if (payload.event !== 'typing' || !payload.data?.matchId) return;

      const match = await pool.query(
        'SELECT user_a_id, user_b_id FROM matches WHERE id = $1 AND (user_a_id = $2 OR user_b_id = $2)',
        [payload.data.matchId, userId]
      );
      const row = match.rows[0];
      if (!row) return;
      const otherUserId = row.user_a_id === userId ? row.user_b_id : row.user_a_id;
      sendToUser(otherUserId, 'typing', { matchId: payload.data.matchId, userId });
    });

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
