import {
  type ConfigPlugin,
  type ExportedConfigWithProps,
  withDangerousMod,
} from 'expo/config-plugins';
import * as fs from 'fs';
import * as path from 'path';

type EmojiSheetPluginProps = {
  searchLocales?: string[];
};

const withEmojiSheet: ConfigPlugin<EmojiSheetPluginProps | void> = (
  config,
  props
) => {
  const searchLocales = (props as EmojiSheetPluginProps | undefined)?.searchLocales ?? [];

  if (searchLocales.length === 0) {
    return config;
  }

  // iOS: Copy locale files to ios/<projectName>/translations/
  config = withDangerousMod(config, [
    'ios',
    (config) => {
      copyLocaleFiles(config, 'ios', searchLocales);
      return config;
    },
  ]);

  // Android: Copy locale files to android/app/src/main/assets/translations/
  config = withDangerousMod(config, [
    'android',
    (config) => {
      copyLocaleFiles(config, 'android', searchLocales);
      return config;
    },
  ]);

  return config;
};

function copyLocaleFiles(
  config: ExportedConfigWithProps,
  platform: 'ios' | 'android',
  locales: string[]
) {
  const projectRoot = config.modRequest.projectRoot;

  // Find the translations directory in the npm package
  const packageTranslationsDir = path.resolve(
    projectRoot,
    'node_modules',
    'expo-native-sheet-emojis',
    'translations'
  );

  if (!fs.existsSync(packageTranslationsDir)) {
    console.warn(
      '[expo-native-sheet-emojis] translations/ directory not found in package. Run the build-emoji-translations script first.'
    );
    return;
  }

  let targetDir: string;
  if (platform === 'ios') {
    // For iOS, copy into the module's bundle resources
    // The podspec includes translations/*.json, so we copy to the pod's source
    targetDir = path.resolve(
      projectRoot,
      'node_modules',
      'expo-native-sheet-emojis',
      'ios',
      'translations'
    );
  } else {
    // For Android, copy into the module's assets
    targetDir = path.resolve(
      projectRoot,
      'node_modules',
      'expo-native-sheet-emojis',
      'android',
      'src',
      'main',
      'assets',
      'translations'
    );
  }

  fs.mkdirSync(targetDir, { recursive: true });

  for (const locale of locales) {
    const sourceFile = path.join(packageTranslationsDir, `${locale}.json`);
    const targetFile = path.join(targetDir, `${locale}.json`);

    if (fs.existsSync(sourceFile)) {
      fs.copyFileSync(sourceFile, targetFile);
    } else {
      console.warn(
        `[expo-native-sheet-emojis] Translation file not found for locale: ${locale}`
      );
    }
  }
}

module.exports = withEmojiSheet;
