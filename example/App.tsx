import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  useColorScheme,
} from 'react-native';
import { EmojiSheetModule, EmojiSheetView, lightTheme, darkTheme } from 'expo-native-sheet-emojis';

export default function App() {
  const systemScheme = useColorScheme();
  const [isDark, setIsDark] = useState(systemScheme === 'dark');
  const [selectedEmoji, setSelectedEmoji] = useState<string | null>(null);
  const [showEmbedded, setShowEmbedded] = useState(false);

  const theme = isDark ? darkTheme : lightTheme;
  const bg = isDark ? '#1A1A2E' : '#FFFFFF';
  const textColor = isDark ? '#FFFFFF' : '#000000';

  const handlePresent = async () => {
    const result = await EmojiSheetModule.present({
      theme,
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
      categoryBarPosition: 'bottom',
      columns: 8,
      emojiSize: 28,
      excludeEmojis: ['pile_of_poo'],
    });

    if (!result.cancelled) {
      setSelectedEmoji(result.emoji);
    }
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: bg }]}>
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
        style={[styles.button, { backgroundColor: isDark ? '#333' : '#DDD' }]}
        onPress={() => setIsDark(!isDark)}
      >
        <Text style={[styles.buttonText, { color: textColor }]}>
          Toggle Theme ({isDark ? 'Dark' : 'Light'})
        </Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={[styles.button, { backgroundColor: isDark ? '#333' : '#DDD' }]}
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
            theme={isDark ? 'dark' : 'light'}
            onEmojiSelected={(emoji) => setSelectedEmoji(emoji)}
          />
        </View>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    paddingTop: 60,
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
  embeddedContainer: {
    flex: 1,
    width: '100%',
    marginTop: 16,
  },
  embeddedView: {
    flex: 1,
  },
});
