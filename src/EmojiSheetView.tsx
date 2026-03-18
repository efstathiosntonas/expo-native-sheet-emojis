import { requireNativeView } from 'expo';
import type * as React from 'react';
import type {
  EmojiSheetNativeViewProps,
  EmojiSheetViewProps,
} from './EmojiSheetModule.types';

const NativeView: React.ComponentType<EmojiSheetNativeViewProps> =
  requireNativeView('EmojiSheet');

export default function EmojiSheetView({
  onEmojiSelected,
  theme,
  translations,
  categoryBarPosition,
  columns,
  emojiSize,
  recentLimit,
  showSearch,
  showRecents,
  enableSkinTones,
  excludeEmojis,
  ...rest
}: EmojiSheetViewProps) {
  const resolvedTheme = typeof theme === 'object' ? 'custom' : theme;

  // For custom themes, we pass individual color props through the native view
  // For now, the declarative view supports 'dark' | 'light' string themes
  // Custom theme object support would require additional native view props

  return (
    <NativeView
      {...rest}
      theme={resolvedTheme}
      categoryBarPosition={categoryBarPosition}
      columns={columns}
      emojiSize={emojiSize}
      recentLimit={recentLimit}
      showSearch={showSearch}
      showRecents={showRecents}
      enableSkinTones={enableSkinTones}
      excludeEmojis={excludeEmojis}
      searchPlaceholder={translations?.searchPlaceholder}
      noResultsText={translations?.noResultsText}
      categoryNames={translations?.categoryNames}
      onEmojiSelected={({ nativeEvent }) => {
        onEmojiSelected(nativeEvent.emoji);
      }}
    />
  );
}
