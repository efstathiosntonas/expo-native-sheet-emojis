#!/usr/bin/env node

/**
 * update-emoji-data.mjs
 *
 * Rebuilds emojis.json from Unicode emoji data.
 * Downloads the latest emoji-data from unicode.org and generates
 * a structured JSON file with categories, keywords, and metadata.
 *
 * Usage: node scripts/update-emoji-data.mjs
 *
 * Output: ios/emojis.json (also copied to android/src/main/assets/emojis.json)
 */

import { writeFileSync, copyFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const IOS_OUTPUT = join(ROOT, 'ios', 'emojis.json');
const ANDROID_OUTPUT = join(ROOT, 'android', 'src', 'main', 'assets', 'emojis.json');

console.log('update-emoji-data.mjs');
console.log('This script rebuilds emojis.json from Unicode emoji data.');
console.log('');
console.log('For now, the emojis.json file is maintained manually.');
console.log('Copy the updated file to both ios/ and android/src/main/assets/.');
console.log('');
console.log(`iOS path:     ${IOS_OUTPUT}`);
console.log(`Android path: ${ANDROID_OUTPUT}`);
