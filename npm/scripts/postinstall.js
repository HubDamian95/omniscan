#!/usr/bin/env node
'use strict';

const https = require('https');
const fs = require('fs');
const path = require('path');
const os = require('os');

const pkg = require('../package.json');
const platform = os.platform();

const assetMap = {
  linux:  'omniscan-linux-x86_64',
  win32:  'omniscan-windows-x86_64.exe',
  darwin: 'omniscan-macos-arm64',
};

const asset = assetMap[platform];
if (!asset) {
  console.warn(`omniscan: unsupported platform "${platform}" — binary not downloaded.`);
  console.warn('You can run omniscan directly from Python: pip install omniscan');
  process.exit(0);
}

const binaryName = platform === 'win32' ? 'omniscan.exe' : 'omniscan';
const binDir = path.join(__dirname, '..', 'bin');
const dest = path.join(binDir, binaryName);

if (!fs.existsSync(binDir)) fs.mkdirSync(binDir, { recursive: true });

const url = `https://github.com/HubDamian95/omniscan/releases/download/v${pkg.version}/${asset}`;

function download(url, dest, cb) {
  const file = fs.createWriteStream(dest);
  https.get(url, (res) => {
    if (res.statusCode === 301 || res.statusCode === 302) {
      file.close();
      fs.unlinkSync(dest);
      return download(res.headers.location, dest, cb);
    }
    if (res.statusCode !== 200) {
      file.close();
      fs.unlinkSync(dest);
      return cb(new Error(`HTTP ${res.statusCode}`));
    }
    res.pipe(file);
    file.on('finish', () => file.close(cb));
    file.on('error', cb);
  }).on('error', (err) => {
    try { fs.unlinkSync(dest); } catch (_) {}
    cb(err);
  });
}

console.log(`omniscan: downloading binary for ${platform} (v${pkg.version})...`);
download(url, dest, (err) => {
  if (err) {
    console.error(`omniscan: download failed — ${err.message}`);
    console.error(`Manual download: ${url}`);
    process.exit(1);
  }
  if (platform !== 'win32') fs.chmodSync(dest, 0o755);
  console.log('omniscan: ready.');
});
