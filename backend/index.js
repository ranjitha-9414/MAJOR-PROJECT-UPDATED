require('dotenv').config();
const express = require('express');
const cors = require('cors');

// Optional: initialize firebase-admin here when you add service account.
// const admin = require('firebase-admin');
// const serviceAccount = require('./serviceAccountKey.json');
// admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const app = express();
app.use(cors());
app.use(express.json());

// Simple in-memory OTP store for demo
const otpStore = new Map();

app.post('/api/auth/send-otp', (req, res) => {
  const { phone } = req.body || {};
  if (!phone) return res.status(400).json({ error: 'phone required' });
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  otpStore.set(phone, otp);
  console.log('OTP for', phone, otp);
  return res.json({ ok: true, phone, otpSent: true });
});

app.post('/api/auth/verify-otp', (req, res) => {
  const { phone, otp } = req.body || {};
  if (!phone || !otp) return res.status(400).json({ error: 'phone and otp required' });
  const expected = otpStore.get(phone);
  if (expected === otp) {
    otpStore.delete(phone);
    return res.json({ ok: true, verified: true });
  }
  return res.status(400).json({ ok: false, verified: false });
});

// stub endpoints
app.get('/api/health', (req, res) => res.json({ ok: true }));

app.post('/api/complaints', (req, res) => {
  // validate and store complaint in Firestore via firebase-admin when configured
  return res.json({ ok: true, id: Date.now().toString() });
});

app.listen(process.env.PORT || 3000, () => {
  console.log('RailAid backend listening on', process.env.PORT || 3000);
});
