import { NativeModule, requireNativeModule } from 'expo';
import type { EmojiSheetResult, EmojiSheetPresentOptions, EmojiSheetTheme } from './EmojiSheetModule.types';

type NativeOptions = Record<string, unknown>;

function flattenOptions(options: EmojiSheetPresentOptions): NativeOptions {
  const flat: NativeOptions = {};

  // Theme
  if (options.theme) {
    if (typeof options.theme === 'string') {
      flat.theme = options.theme;
    } else {
      const theme = options.theme as EmojiSheetTheme;
      flat.theme = 'custom';
      flat.backgroundColor = theme.backgroundColor;
      flat.searchBarBackgroundColor = theme.searchBarBackgroundColor;
      flat.textColor = theme.textColor;
      flat.textSecondaryColor = theme.textSecondaryColor;
      flat.accentColor = theme.accentColor;
      flat.dividerColor = theme.dividerColor;
      if (theme.searchTextColor) flat.searchTextColor = theme.searchTextColor;
      if (theme.placeholderTextColor) flat.placeholderTextColor = theme.placeholderTextColor;
      if (theme.selectionColor) flat.selectionColor = theme.selectionColor;
      if (theme.categoryIconColor) flat.categoryIconColor = theme.categoryIconColor;
      if (theme.categoryActiveIconColor) flat.categoryActiveIconColor = theme.categoryActiveIconColor;
      if (theme.categoryActiveBackgroundColor) flat.categoryActiveBackgroundColor = theme.categoryActiveBackgroundColor;
      if (theme.handleColor) flat.handleColor = theme.handleColor;
      if (theme.categoryBarBackgroundColor) flat.categoryBarBackgroundColor = theme.categoryBarBackgroundColor;
    }
  }

  // Translations
  if (options.translations) {
    if (options.translations.searchPlaceholder) flat.searchPlaceholder = options.translations.searchPlaceholder;
    if (options.translations.noResultsText) flat.noResultsText = options.translations.noResultsText;
    if (options.translations.categoryNames) flat.categoryNames = options.translations.categoryNames;
  }

  // Layout & behavior
  if (options.snapPoints) flat.snapPoints = options.snapPoints;
  if (options.categoryBarPosition) flat.categoryBarPosition = options.categoryBarPosition;
  if (options.columns != null) flat.columns = options.columns;
  if (options.emojiSize != null) flat.emojiSize = options.emojiSize;
  if (options.recentLimit != null) flat.recentLimit = options.recentLimit;
  if (options.showSearch != null) flat.showSearch = options.showSearch;
  if (options.showRecents != null) flat.showRecents = options.showRecents;
  if (options.enableSkinTones != null) flat.enableSkinTones = options.enableSkinTones;
  if (options.enableHaptics != null) flat.enableHaptics = options.enableHaptics;
  if (options.gestureEnabled != null) flat.gestureEnabled = options.gestureEnabled;
  if (options.backdropOpacity != null) flat.backdropOpacity = options.backdropOpacity;
  if (options.excludeEmojis) flat.excludeEmojis = options.excludeEmojis;

  return flat;
}

declare class EmojiSheetModuleType extends NativeModule {
  present(options: NativeOptions): Promise<EmojiSheetResult>;
  dismiss(): Promise<void>;
}

const NativeEmojiSheet = requireNativeModule<EmojiSheetModuleType>('EmojiSheet');

export type { EmojiSheetResult };

export default {
  present(options: EmojiSheetPresentOptions = {}): Promise<EmojiSheetResult> {
    return NativeEmojiSheet.present(flattenOptions(options));
  },
  dismiss(): Promise<void> {
    return NativeEmojiSheet.dismiss();
  },
};
