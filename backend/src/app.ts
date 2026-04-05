import express from 'express';
import cors from 'cors';
import path from 'path';
import { initializeDatabase } from './models/database';
import router from './routes';

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
  console.log(`\n🚀 여행 예약 서버가 실행 중입니다!`);
  console.log(`   포트: ${PORT}`);
  console.log(`   API: http://localhost:${PORT}/api`);
  console.log(`   프론트엔드: http://localhost:${PORT}\n`);
});

export default app;
