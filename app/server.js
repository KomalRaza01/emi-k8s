const express = require('express');
const path = require('path');
const os = require('os');
const { MongoClient } = require('mongodb');

const PORT = process.env.PORT || 3000;
const MONGO_URL = process.env.MONGO_URL;
if (!MONGO_URL) {
  console.error('MONGO_URL environment variable is required');
  process.exit(1);
}

const POD_NAME = process.env.HOSTNAME || os.hostname();
function podIp() {
  if (process.env.POD_IP) return process.env.POD_IP;
  for (const list of Object.values(os.networkInterfaces()))
    for (const i of list)
      if (i.family === 'IPv4' && !i.internal) return i.address;
  return 'unknown';
}
const POD_IP = podIp();

let client = null;
let calculations = null;

async function connectLoop() {
  while (true) {
    try {
      const c = new MongoClient(MONGO_URL, { serverSelectionTimeoutMS: 5000, maxPoolSize: 20 });
      await c.connect();
      client = c;
      calculations = c.db().collection('calculations');
      console.log('Connected to MongoDB');
      return;
    } catch (err) {
      console.error('MongoDB connection failed, retrying in 3s:', err.message);
      await new Promise(r => setTimeout(r, 3000));
    }
  }
}

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

function positive(v) {
  const n = (typeof v === 'string' && v.trim() !== '') ? Number(v) : v;
  return (typeof n === 'number' && Number.isFinite(n) && n > 0) ? n : null;
}
const round2 = x => Math.round(x * 100) / 100;

app.post('/api/emi', async (req, res) => {
  const body = req.body || {};
  const P = positive(body.P), rate = positive(body.rate), n = positive(body.n);
  if (P === null || rate === null || n === null || !Number.isInteger(n) ||
      P > 1e12 || rate > 100 || n > 1200) {
    return res.status(400).json({ error: 'P, rate and n must be positive numbers (n an integer number of months)' });
  }
  const r = rate / 12 / 100;
  const f = Math.pow(1 + r, n);
  const emi = (P * r * f) / (f - 1);
  const total = emi * n;
  const result = {
    emi: round2(emi),
    totalPayment: round2(total),
    totalInterest: round2(total - P),
    servedBy: POD_NAME,
    podIp: POD_IP
  };
  if (!calculations) return res.status(503).json({ error: 'Database not ready' });
  try {
    await calculations.insertOne({
      principal: P, rate, months: n, emi: result.emi,
      servedBy: POD_NAME, createdAt: new Date()
    });
  } catch (err) {
    console.error('insert failed:', err.message);
    return res.status(500).json({ error: 'Could not save calculation' });
  }
  res.json(result);
});

app.get('/api/history', async (req, res) => {
  if (!calculations) return res.status(503).json({ error: 'Database not ready' });
  try {
    const rows = await calculations.find({}, { projection: { _id: 0 } })
      .sort({ createdAt: -1 }).limit(10).toArray();
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Could not read history' });
  }
});

app.get('/health', async (req, res) => {
  try {
    if (!client) throw new Error('not connected');
    await Promise.race([
      client.db().command({ ping: 1 }),
      new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), 2000))
    ]);
    res.status(200).send('OK');
  } catch (err) {
    res.status(503).send('MongoDB unreachable');
  }
});

const server = app.listen(PORT, () => {
  console.log(`emi-web listening on ${PORT} (pod ${POD_NAME}, ip ${POD_IP})`);
  connectLoop();
});

// graceful shutdown: rolling update mein koi request drop na ho
function shutdown() {
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 8000).unref();
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
