import 'dotenv/config';
import 'express-async-errors';
import express from 'express';
import cors from 'cors';
import path from 'path';
import authRoutes from './routes/auth';
import preferencesRoutes from './routes/preferences';
import jackpotRoutes from './routes/jackpot';
import profileRoutes from './routes/profile';
import categoriesRoutes from './routes/categories';
import matchesRoutes from './routes/matches';
import usersRoutes from './routes/users';
import adminRoutes from './routes/admin';
import { setupWebSocketServer } from './ws';

const app = express();
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

app.use('/auth', authRoutes);
app.use('/preferences', preferencesRoutes);
app.use('/jackpot', jackpotRoutes);
app.use('/profile', profileRoutes);
app.use('/categories', categoriesRoutes);
app.use('/matches', matchesRoutes);
app.use('/users', usersRoutes);
app.use('/admin', adminRoutes);

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// Catches anything thrown/rejected in a route handler (including duplicate-key
// errors and other DB constraint violations) so a single bad request returns
// an error response instead of taking the whole process down.
app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  if (err?.code === '23505') {
    return res.status(409).json({ error: 'That value is already in use' });
  }
  res.status(500).json({ error: 'Internal server error' });
});

// Last-resort safety net: log and keep serving other requests instead of
// crashing the entire process on an error that slipped past Express.
process.on('unhandledRejection', (reason) => {
  console.error('Unhandled rejection:', reason);
});
process.on('uncaughtException', (err) => {
  console.error('Uncaught exception:', err);
});

const port = process.env.PORT ?? 3000;
const server = app.listen(port, () => console.log(`AdictLove API listening on port ${port}`));
setupWebSocketServer(server);
