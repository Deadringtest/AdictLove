import 'dotenv/config';
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

const port = process.env.PORT ?? 3000;
const server = app.listen(port, () => console.log(`AdictLove API listening on port ${port}`));
setupWebSocketServer(server);
