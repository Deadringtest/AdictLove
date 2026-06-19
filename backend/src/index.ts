import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import authRoutes from './routes/auth';
import preferencesRoutes from './routes/preferences';
import jackpotRoutes from './routes/jackpot';

const app = express();
app.use(cors());
app.use(express.json());

app.use('/auth', authRoutes);
app.use('/preferences', preferencesRoutes);
app.use('/jackpot', jackpotRoutes);

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

const port = process.env.PORT ?? 3000;
app.listen(port, () => console.log(`AdictLove API listening on port ${port}`));
