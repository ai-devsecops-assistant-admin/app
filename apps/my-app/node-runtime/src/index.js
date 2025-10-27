const express = require('express');
const pino = require('pino');

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  transport: process.env.NODE_ENV !== 'production' ? {
    target: 'pino-pretty',
    options: {
      colorize: true
    }
  } : undefined
});

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

app.use((req, res, next) => {
  logger.info({
    method: req.method,
    path: req.path,
    ip: req.ip
  }, 'Incoming request');
  next();
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/ready', (req, res) => {
  res.json({ status: 'ready', timestamp: new Date().toISOString() });
});

app.post('/process', async (req, res) => {
  try {
    const { type, data } = req.body;
    logger.info({ type }, 'Processing artifact');

    res.json({
      success: true,
      processed: true,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error({ error: error.message }, 'Processing failed');
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

const server = app.listen(port, () => {
  logger.info({ port }, 'Node runtime service started');
});

process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
});
