import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import path from 'path';
import authRoutes from './routes/auth';
import preferencesRoutes from './routes/preferences';
import jackpotRoutes from './routes/jackpot';
import profileRoutes from './routes/profile';
import categoriesRoutes from './routes/categories';

const app = express();
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

app.use('/auth', authRoutes);
app.use('/preferences', preferencesRoutes);
app.use('/jackpot', jackpotRoutes);
app.use('/profile', profileRoutes);
app.use('/categories', categoriesRoutes);

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

const port = process.env.PORT ?? 3000;
app.listen(port, () => console.log(`AdictLove API listening on port ${port}`));
