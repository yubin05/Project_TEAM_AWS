import express from 'express';
import cors from 'cors';
import path from 'path';
import morgan from 'morgan';
import { initializeDatabase } from './models/database';
import router from './routes';
import logger from './utils/logger';

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(morgan('combined', { stream: { write: (msg) => logger.http(msg.trim()) } }));

// Serve static files (frontend)
app.use(express.static(path.join(__dirname, '../../frontend/public')));

// API routes
app.use('/api', router);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString(), service: 'Travel Booking API' });
});

// Fallback for SPA
app.get('*', (req, res) => {
  if (!req.path.startsWith('/api')) {
    res.sendFile(path.join(__dirname, '../../frontend/public/index.html'));
  }
});

// Initialize database and start server
initializeDatabase();

app.listen(PORT, () => {
  logger.info('Server started', { port: PORT });
});

export default app;
