import express from 'express';
import cors from 'cors';
import { config, isLocal } from './config';
import { initializeDatabase } from './models/database';
import router from './routes';

const app = express();

app.use(cors({
  origin:         config.cors.origin,
  methods:        ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

app.use('/api', router);

app.get('/health', (_req, res) => {
  res.json({
    status:    'ok',
    timestamp: new Date().toISOString(),
    mode:      config.mode,           // 'local' | 'aws'
    service:   'Travel Booking API',
  });
});

async function bootstrap() {
  await initializeDatabase();

  app.listen(config.port, () => {
    console.log(`\n🚀 서버 실행 중`);
    console.log(`   포트  : ${config.port}`);
    console.log(`   모드  : ${config.mode.toUpperCase()} ${isLocal ? '(로컬 Docker)' : '(AWS EC2)'}`);
    console.log(`   API   : http://localhost:${config.port}/api\n`);
  });
}

bootstrap().catch((err) => {
  console.error('서버 시작 실패:', err);
  process.exit(1);
});

export default app;
