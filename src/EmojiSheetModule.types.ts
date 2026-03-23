import { type ViewProps } from 'react-native';

export type EmojiSheetTheme = {
  backgroundColor: string;
  searchBarBackgroundColor: string;
  textColor: string;
  textSecondaryColor: string;
  searchTextColor?: string;
  placeholderTextColor?: string;
  accentColor: string;
  selectionColor?: string;
  categoryIconColor?: string;
  categoryActiveIconColor?: string;
  categoryActiveBackgroundColor?: string;
  handleColor?: string;
  dividerColor: string;
  categoryBarBackgroundColor?: string;
};

export type EmojiCategory =
  | 'frequently_used'
  | 'smileys_emotion'
  | 'people_body'
  | 'animals_nature'
  | 'food_drink'
  | 'travel_places'
  | 'activities'
  | 'objects'
  | 'symbols'
  | 'flags';

export type EmojiSheetTranslations = {
  searchPlaceholder?: string;
  noResultsText?: string;
  categoryNames?: Partial<Record<EmojiCategory, string>>;
};

export type EmojiSheetPresentOptions = {
  theme?: EmojiSheetTheme | 'dark' | 'light' | 'system';
  translations?: EmojiSheetTranslations;
  snapPoints?: [number, number];
  categoryBarPosition?: 'top' | 'bottom';
  columns?: number;
  emojiSize?: number;
  recentLimit?: number;
  showSearch?: boolean;
  showRecents?: boolean;
  enableSkinTones?: boolean;
  enableHaptics?: boolean;
  enableAnimations?: boolean;
  gestureEnabled?: boolean;
  backdropOpacity?: number;
  excludeEmojis?: string[];
};

export type EmojiSheetResult =
  | { emoji: string; cancelled?: never }
  | { cancelled: true; emoji?: never };

export type EmojiSelectionListener = (event: { nativeEvent: { emoji: string } }) => void;

export type EmojiSheetViewProps = ViewProps & {
  onEmojiSelected: (emoji: string) => void;
  theme?: EmojiSheetTheme | 'dark' | 'light' | 'system';
  translations?: EmojiSheetTranslations;
  categoryBarPosition?: 'top' | 'bottom';
  columns?: number;
  emojiSize?: number;
  recentLimit?: number;
  showSearch?: boolean;
  showRecents?: boolean;
  enableSkinTones?: boolean;
  enableHaptics?: boolean;
  enableAnimations?: boolean;
  excludeEmojis?: string[];
};

export type EmojiSheetNativeViewProps = ViewProps & {
  onEmojiSelected: EmojiSelectionListener;
  theme?: string;
  categoryBarPosition?: string;
  columns?: number;
  emojiSize?: number;
  recentLimit?: number;
  showSearch?: boolean;
  showRecents?: boolean;
  enableSkinTones?: boolean;
  enableHaptics?: boolean;
  enableAnimations?: boolean;
  searchPlaceholder?: string;
  noResultsText?: string;
  categoryNames?: Partial<Record<EmojiCategory, string>>;
  excludeEmojis?: string[];
};
