require('dotenv').config();
const express = require('express');
const cors = require('cors');
const axios = require('axios');
const FormData = require('form-data');

// Optional: initialize firebase-admin here when you add service account.
// const admin = require('firebase-admin');
// const serviceAccount = require('./serviceAccountKey.json');
// admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const app = express();
app.use(cors());
// Increase body size limits to accept base64 image payloads from the Flutter client
app.use(express.json({ limit: process.env.EXPRESS_JSON_LIMIT || '50mb' }));
app.use(express.urlencoded({ extended: true, limit: process.env.EXPRESS_JSON_LIMIT || '50mb' }));

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

// Classification proxy: forwards description + optional base64 image to the Flask model
app.post('/api/classify', async (req, res) => {
  try {
    const { description, photoBase64 } = req.body || {};

    // Defensive validation: both image and text are required by your Flask model
    if (!description || !photoBase64) {
      return res.status(400).json({ ok: false, error: 'description and photoBase64 are required' });
    }

    const flaskUrl = process.env.FLASK_MODEL_URL || 'http://127.0.0.1:5000/predict';

    // Always send form-data using field name `text` (Flask expects 'text')
    const form = new FormData();
    form.append('text', description || '');
    if (photoBase64) {
      const buffer = Buffer.from(photoBase64, 'base64');
      form.append('image', buffer, { filename: 'upload.jpg', contentType: 'image/jpeg' });
    }

    flaskResp = await axios.post(flaskUrl, form, { headers: form.getHeaders(), timeout: 20000 });

    // Normalize flask response into a stable shape { category, confidence, source }
    const data = flaskResp.data || {};
    // Flask app typically returns final_decision or ensemble containing { label, confidence, source }
    let cat = null;
    let conf = 0.0;
    let src = null;
    if (data && typeof data === 'object') {
      const finalDecision = data.final_decision || data.ensemble || data.ens || data;
      if (finalDecision && typeof finalDecision === 'object') {
        cat = finalDecision.label || finalDecision.name || finalDecision.category || null;
        conf = Number(finalDecision.confidence ?? finalDecision.score ?? 0.0) || 0.0;
        src = finalDecision.source || null;
      }
    }

    const normalized = { category: cat, confidence: conf, source: src, raw: data };
    return res.json({ ok: true, classification: normalized });
  } catch (err) {
    console.error('classification error', err?.response?.data || err.message || err);
    return res.status(500).json({ ok: false, error: 'classification failed', details: err?.message });
  }
});

app.listen(process.env.PORT || 3000, () => {
  console.log('RailAid backend listening on', process.env.PORT || 3000);
});
