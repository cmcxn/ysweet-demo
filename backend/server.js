import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import { DocumentManager } from '@y-sweet/sdk';

dotenv.config();
const app = express();
app.use(cors());
app.use(express.json());

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const clientDir = process.env.CLIENT_DIR || path.resolve(__dirname, '../client');
app.use(express.static(clientDir));

const CONNECTION_STRING = process.env.CONNECTION_STRING;
if (!CONNECTION_STRING) {
  console.error('请在 .env 中设置 CONNECTION_STRING');
  process.exit(1);
}
const manager = new DocumentManager(CONNECTION_STRING);

const PUBLIC_YSWEET_URL = process.env.PUBLIC_YSWEET_URL;

const connectionUrl = (() => {
  try {
    return new URL(
      CONNECTION_STRING.replace(/^yss?:/, (scheme) =>
        scheme === 'yss:' ? 'https:' : 'http:'
      )
    );
  } catch (error) {
    console.warn('无法解析 CONNECTION_STRING，将跳过公共地址推断。', error);
    return null;
  }
})();

function getDefaultPublicWsUrl() {
  if (!connectionUrl) return null;
  const isSecure = CONNECTION_STRING.startsWith('yss://');
  const protocol = isSecure ? 'wss:' : 'ws:';
  const hostname =
    connectionUrl.hostname === 'ysweet'
      ? 'localhost'
      : connectionUrl.hostname;
  const port = connectionUrl.port ? `:${connectionUrl.port}` : '';
  return `${protocol}//${hostname}${port}`;
}

function applyPublicUrlOverride(clientToken) {
  const targetUrl = PUBLIC_YSWEET_URL || getDefaultPublicWsUrl();
  if (!targetUrl) {
    return clientToken;
  }

  try {
    const overrideUrl = new URL(targetUrl);
    const wsUrl = new URL(clientToken.url);
    wsUrl.protocol = overrideUrl.protocol;
    wsUrl.hostname = overrideUrl.hostname;
    wsUrl.port = overrideUrl.port;

    const baseUrl = new URL(clientToken.baseUrl);
    if (overrideUrl.protocol === 'wss:') {
      baseUrl.protocol = 'https:';
    } else if (overrideUrl.protocol === 'ws:') {
      baseUrl.protocol = 'http:';
    } else {
      baseUrl.protocol = overrideUrl.protocol;
    }
    baseUrl.hostname = overrideUrl.hostname;
    baseUrl.port = overrideUrl.port;

    return {
      ...clientToken,
      url: wsUrl.toString(),
      baseUrl: baseUrl.toString(),
    };
  } catch (error) {
    console.warn('PUBLIC_YSWEET_URL 无效，已忽略。', error);
    return clientToken;
  }
}

app.post('/api/auth', async (req, res) => {
  try {
    const docId = req.body?.docId;
    if (!docId) return res.status(400).json({ error: 'docId 必填' });
    const clientToken = await manager.getOrCreateDocAndToken(docId);
    res.json(applyPublicUrlOverride(clientToken));
  } catch (err) {
    console.error('生成 client token 出错', err);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`Auth 服务器已启动，监听端口 ${PORT}`));
