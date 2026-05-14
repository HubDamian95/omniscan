#!/usr/bin/env node
'use strict';

const { spawnSync } = require('child_process');
const path = require('path');
const os = require('os');
const fs = require('fs');

const binaryName = os.platform() === 'win32' ? 'omniscan.exe' : 'omniscan';
const binaryPath = path.join(__dirname, binaryName);

if (!fs.existsSync(binaryPath)) {
  console.error('omniscan: binary not found. Try reinstalling: npm install -g omniscan');
  process.exit(1);
}

const result = spawnSync(binaryPath, process.argv.slice(2), { stdio: 'inherit' });
process.exit(result.status ?? 1);
