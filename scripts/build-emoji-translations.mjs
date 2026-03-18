#!/usr/bin/env node

/**
 * build-emoji-translations.mjs
 *
 * Generates per-locale translation files from Unicode CLDR emoji annotation data.
 * Each file maps emoji characters to arrays of search keywords in that locale.
 *
 * Usage: node scripts/build-emoji-translations.mjs
 *
 * Prerequisites:
 *   npm install cldr-annotations-full
 *   (or provide a path to CLDR annotation data)
 *
 * Output: translations/<locale>.json files
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const TRANSLATIONS_DIR = join(ROOT, 'translations');
const EMOJIS_PATH = join(ROOT, 'ios', 'emojis.json');

const SUPPORTED_LOCALES = [
  'ca',
  'cs',
  'de',
  'el',
  'en',
  'es',
  'fi',
  'fr',
  'hi',
  'hu',
  'it',
  'ja',
  'ko',
  'nl',
  'pl',
  'pt',
  'ru',
  'sv',
  'tr',
  'uk',
  'zh',
];

function main() {
  // Load base emoji data to get the list of all emoji characters
  if (!existsSync(EMOJIS_PATH)) {
    console.error('emojis.json not found. Run update-emoji-data.mjs first.');
    process.exit(1);
  }

  const emojis = JSON.parse(readFileSync(EMOJIS_PATH, 'utf-8'));
  const allEmoji = new Set();
  for (const section of emojis) {
    for (const item of section.data) {
      allEmoji.add(item.emoji);
    }
  }

  console.log(`Found ${allEmoji.size} emoji characters`);

  // Try to find CLDR annotation data
  const cldrPath = join(ROOT, 'node_modules', 'cldr-annotations-full', 'annotations');

  if (!existsSync(cldrPath)) {
    console.error(
      'CLDR annotations not found. Install with:\n' +
        '  npm install --save-dev cldr-annotations-full\n\n' +
        'Then re-run this script.'
    );
    process.exit(1);
  }

  mkdirSync(TRANSLATIONS_DIR, { recursive: true });

  for (const locale of SUPPORTED_LOCALES) {
    const annotationFile = join(cldrPath, locale, 'annotations.json');
    const derivedFile = join(cldrPath, locale, 'annotationsDerived.json');

    const keywords = {};

    for (const file of [annotationFile, derivedFile]) {
      if (!existsSync(file)) continue;

      try {
        const data = JSON.parse(readFileSync(file, 'utf-8'));
        const annotations =
          data?.annotations?.annotations ?? data?.annotationsDerived?.annotations ?? {};

        for (const [emoji, entry] of Object.entries(annotations)) {
          if (!allEmoji.has(emoji)) continue;
          const kw = entry.default ?? [];
          if (kw.length > 0) {
            if (!keywords[emoji]) keywords[emoji] = [];
            keywords[emoji].push(...kw);
          }
        }
      } catch {
        // Skip malformed files
      }
    }

    const outputPath = join(TRANSLATIONS_DIR, `${locale}.json`);
    writeFileSync(outputPath, JSON.stringify(keywords, null, 0), 'utf-8');
    const size = (Buffer.byteLength(JSON.stringify(keywords)) / 1024).toFixed(0);
    console.log(`  ${locale}: ${Object.keys(keywords).length} emoji, ${size}KB`);
  }

  console.log(`\nDone. Translation files written to translations/`);
}

main();
