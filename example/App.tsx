import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  ScrollView,
  useColorScheme,
} from 'react-native';
import { EmojiSheetModule, EmojiSheetView, lightTheme, darkTheme } from 'expo-native-sheet-emojis';

export default function App() {
  const systemScheme = useColorScheme();
  const [themeMode, setThemeMode] = useState<'light' | 'dark' | 'system'>('system');
  const [layoutDirection, setLayoutDirection] = useState<'auto' | 'ltr' | 'rtl'>('auto');
  const [selectedEmoji, setSelectedEmoji] = useState<string | null>(null);
  const [showEmbedded, setShowEmbedded] = useState(false);

  const effectiveDark = themeMode === 'system' ? systemScheme === 'dark' : themeMode === 'dark';
  const theme = themeMode === 'system' ? 'system' : effectiveDark ? darkTheme : lightTheme;
  const bg = effectiveDark ? '#1A1A2E' : '#FFFFFF';
  const textColor = effectiveDark ? '#FFFFFF' : '#000000';

  const cycleTheme = () => {
    setThemeMode((prev) => {
      if (prev === 'light') return 'dark';
      if (prev === 'dark') return 'system';
      return 'light';
    });
  };

  const themeModeLabel = themeMode === 'system' ? 'System' : themeMode === 'dark' ? 'Dark' : 'Light';
  const layoutDirectionLabel =
    layoutDirection === 'auto' ? 'Auto' : layoutDirection === 'rtl' ? 'RTL' : 'LTR';

  const handlePresent = async () => {
    const result = await EmojiSheetModule.present({
      theme,
      layoutDirection,
      translations: {
        searchPlaceholder: 'Find an emoji...',
        noResultsText: 'Nothing found',
      },
      snapPoints: [0.5, 1.0],
      categoryBarPosition: 'top',
      excludeEmojis: ['thumb_down'],
    });

    if (!result.cancelled) {
      setSelectedEmoji(result.emoji);
    }
  };

  const handlePresentBottomBar = async () => {
    const result = await EmojiSheetModule.present({
      theme,
      layoutDirection,
      categoryBarPosition: 'bottom',
      columns: 8,
      emojiSize: 28,
      excludeEmojis: ['pile_of_poo'],
    });

    if (!result.cancelled) {
      setSelectedEmoji(result.emoji);
    }
  };

  const handlePresentRtl = async () => {
    const result = await EmojiSheetModule.present({
      theme,
      layoutDirection: 'rtl',
      translations: {
        searchPlaceholder: 'Find an emoji...',
        noResultsText: 'Nothing found',
      },
      snapPoints: [0.5, 1.0],
      categoryBarPosition: 'top',
      excludeEmojis: ['thumb_down'],
    });

    if (!result.cancelled) {
      setSelectedEmoji(result.emoji);
    }
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: bg }]}>
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <Text style={[styles.title, { color: textColor }]}>expo-native-sheet-emojis</Text>

        {selectedEmoji && <Text style={styles.selectedEmoji}>{selectedEmoji}</Text>}

        <TouchableOpacity
          style={[styles.button, { backgroundColor: '#EA4578' }]}
          onPress={handlePresent}
        >
          <Text style={styles.buttonText}>Present (Top Bar)</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.button, { backgroundColor: '#7E80B6' }]}
          onPress={handlePresentBottomBar}
        >
          <Text style={styles.buttonText}>Present (Bottom Bar)</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.button, { backgroundColor: '#009688' }]}
          onPress={handlePresentRtl}
        >
          <Text style={styles.buttonText}>Present In RTL Layout</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.button, { backgroundColor: effectiveDark ? '#333' : '#DDD' }]}
          onPress={cycleTheme}
        >
          <Text style={[styles.buttonText, { color: textColor }]}>
            Theme: {themeModeLabel}
          </Text>
        </TouchableOpacity>

        <View style={styles.controlGroup}>
          <Text style={[styles.controlLabel, { color: textColor }]}>
            Layout Direction: {layoutDirectionLabel}
          </Text>
          <View style={styles.directionRow}>
            {(['auto', 'ltr', 'rtl'] as const).map((direction) => {
              const isActive = layoutDirection === direction;
              const label =
                direction === 'auto' ? 'Auto' : direction === 'rtl' ? 'RTL' : 'LTR';

              return (
                <TouchableOpacity
                  key={direction}
                  style={[
                    styles.directionButton,
                    {
                      backgroundColor: isActive
                        ? '#EA4578'
                        : effectiveDark
                          ? '#333'
                          : '#E7E7E7',
                    },
                  ]}
                  onPress={() => setLayoutDirection(direction)}
                >
                  <Text
                    style={[
                      styles.directionButtonText,
                      { color: isActive ? '#FFFFFF' : textColor },
                    ]}
                  >
                    {label}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
        </View>

        <TouchableOpacity
          style={[styles.button, { backgroundColor: '#D4A03C' }]}
          onPress={() => EmojiSheetModule.clearRecents()}
        >
          <Text style={styles.buttonText}>Clear Recents</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.button, { backgroundColor: '#D4A03C' }]}
          onPress={() => EmojiSheetModule.clearSkinTonePreferences()}
        >
          <Text style={styles.buttonText}>Clear Skin Tones</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.button, { backgroundColor: effectiveDark ? '#333' : '#DDD' }]}
          onPress={() => setShowEmbedded(!showEmbedded)}
        >
          <Text style={[styles.buttonText, { color: textColor }]}>
            {showEmbedded ? 'Hide' : 'Show'} Embedded View
          </Text>
        </TouchableOpacity>

        {showEmbedded && (
          <View style={styles.embeddedContainer}>
            <EmojiSheetView
              style={styles.embeddedView}
              theme={themeMode === 'system' ? 'system' : effectiveDark ? 'dark' : 'light'}
              layoutDirection={layoutDirection}
              onEmojiSelected={(emoji) => setSelectedEmoji(emoji)}
            />
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollContent: {
    alignItems: 'center',
    paddingTop: 60,
    paddingBottom: 24,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
    marginBottom: 20,
  },
  selectedEmoji: {
    fontSize: 64,
    marginBottom: 20,
  },
  button: {
    paddingHorizontal: 24,
    paddingVertical: 14,
    borderRadius: 12,
    marginBottom: 12,
    minWidth: 240,
    alignItems: 'center',
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  controlGroup: {
    width: '100%',
    alignItems: 'center',
    marginBottom: 12,
  },
  controlLabel: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 10,
  },
  directionRow: {
    flexDirection: 'row',
    gap: 8,
  },
  directionButton: {
    minWidth: 72,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 12,
    alignItems: 'center',
  },
  directionButtonText: {
    fontSize: 15,
    fontWeight: '600',
  },
  embeddedContainer: {
    height: 520,
    width: '100%',
    marginTop: 16,
  },
  embeddedView: {
    flex: 1,
  },
});
