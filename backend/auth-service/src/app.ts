import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import { config } from './config';
import router from './routes';
import logger from './utils/logger';

const app = express();

app.use(cors({ origin: config.cors.origin }));
app.use(express.json());
app.use(morgan('combined', {
  stream: { write: (msg: string) => logger.http(msg.trim()) },
}));

app.use('/', router);

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'auth-service', mode: config.mode });
});

app.listen(config.port, () => {
  logger.info('auth-service started', { port: config.port, mode: config.mode });
});
