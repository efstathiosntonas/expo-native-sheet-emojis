import {
  type ConfigPlugin,
  type ExportedConfigWithProps,
  IOSConfig,
  withDangerousMod,
  withXcodeProject,
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

  // iOS: Add locale files directly to the Xcode project's Copy Bundle Resources phase.
  // This avoids the pod-install-time limitation of s.resources glob evaluation —
  // files are added to the .xcodeproj by prebuild and survive without re-running pod install.
  config = withXcodeProject(config, (config) => {
    const project = config.modResults;
    const projectRoot = config.modRequest.projectRoot;

    const packageTranslationsDir = path.resolve(
      projectRoot,
      'node_modules',
      'expo-native-sheet-emojis',
      'translations'
    );

    if (!fs.existsSync(packageTranslationsDir)) {
      console.warn(
        '[expo-native-sheet-emojis] translations/ directory not found in package.'
      );
      return config;
    }

    const target = project.getFirstTarget();
    if (!target) return config;

    // addResourceFile crashes when no PBXGroup named 'Resources' exists (common in
    // Expo-generated projects). ensureGroupRecursively creates it if absent — this is
    // exactly how expo-asset's own config plugin handles the same situation.
    IOSConfig.XcodeUtils.ensureGroupRecursively(project, 'Resources');

    for (const locale of searchLocales) {
      const absolutePath = path.join(packageTranslationsDir, `${locale}.json`);
      if (!fs.existsSync(absolutePath)) {
        console.warn(
          `[expo-native-sheet-emojis] Translation file not found for locale: ${locale}`
        );
        continue;
      }

      // Path relative to ios/ where the .xcodeproj lives.
      // Xcode copies this file into the app bundle at build time.
      const relativePath = `../node_modules/expo-native-sheet-emojis/translations/${locale}.json`;
      project.addResourceFile(relativePath, { target: target.uuid });
    }

    return config;
  });

  // Android: Copy locale files to the module's assets directory.
  // Note: the module's Gradle copyTranslations task copies all locales at build time for
  // bare React Native projects. For Expo managed workflow this plugin runs first and
  // the Gradle task supplements with any remaining locales.
  config = withDangerousMod(config, [
    'android',
    (config) => {
      copyAndroidLocaleFiles(config, searchLocales);
      return config;
    },
  ]);

  return config;
};

function copyAndroidLocaleFiles(
  config: ExportedConfigWithProps,
  locales: string[]
) {
  const projectRoot = config.modRequest.projectRoot;

  const packageTranslationsDir = path.resolve(
    projectRoot,
    'node_modules',
    'expo-native-sheet-emojis',
    'translations'
  );

  if (!fs.existsSync(packageTranslationsDir)) {
    console.warn(
      '[expo-native-sheet-emojis] translations/ directory not found in package.'
    );
    return;
  }

  const targetDir = path.resolve(
    projectRoot,
    'node_modules',
    'expo-native-sheet-emojis',
    'android',
    'src',
    'main',
    'assets',
    'translations'
  );

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
