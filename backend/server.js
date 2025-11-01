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

app.post('/api/auth', async (req, res) => {
  try {
    const docId = req.body?.docId;
    if (!docId) return res.status(400).json({ error: 'docId 必填' });
    const clientToken = await manager.getOrCreateDocAndToken(docId);
    res.json(clientToken);
  } catch (err) {
    console.error('生成 client token 出错', err);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`Auth 服务器已启动，监听端口 ${PORT}`));
