# expo-native-sheet-emojis

A fully native emoji picker bottom sheet for React Native. Built entirely in Swift (iOS) and Kotlin (Android) -- every interaction runs at 60+ FPS with zero bridge overhead.

## Highlights

- **1900+ emojis** across 9 categories (Unicode Emoji up to v16.0), rendered at 60+ FPS
- **60+ FPS everywhere** -- native UICollectionView (iOS) and RecyclerView (Android) with no JS bridge involvement during scrolling, searching, or animations
- Fully native on both platforms -- no JavaScript emoji rendering, no web views, no React re-renders
- Search across 21 languages powered by [Unicode CLDR](https://cldr.unicode.org/) -- the industry-standard source for emoji annotations used by iOS, Android, and major platforms. Runs on a background thread to keep the UI thread free
- Bottom sheet with configurable snap points and smooth spring animations
- Skin tone selection with long-press gesture
- Frequently used tracking persisted across app launches
- Structured theming with light/dark presets and full custom theme support
- Configurable grid layout (columns, emoji size)
- Floating pill category bar (bottom) or inline strip (top)
- Expo config plugin for per-locale translation bundling -- English-only apps pay zero extra bundle size

## Demo

| iOS | Android |
|-|-|
| <video src="https://github.com/user-attachments/assets/26fa9d69-5bea-4335-936c-6a82d77c6047" width="300" /> | <video src="https://github.com/user-attachments/assets/6de07893-732b-40a0-8961-80f149c53e9e" width="300" /> |

## Installation

```bash
npx expo install expo-native-sheet-emojis
```

For bare workflow projects, run `npx expo prebuild` after installation.

For bare React Native projects using `expo-modules-core`:

```bash
yarn add expo-native-sheet-emojis
cd ios && pod install
```

## Quick Start

The imperative API presents a native bottom sheet and returns the selected emoji:

```typescript
import { EmojiSheetModule } from 'expo-native-sheet-emojis';

async function pickEmoji() {
  const result = await EmojiSheetModule.present({
    theme: 'dark',
    categoryBarPosition: 'top',
  });

  if (!result.cancelled) {
    console.log('Selected:', result.emoji);
  }
}
```

## Declarative Usage

Embed the emoji picker directly in your component tree:

```tsx
import { EmojiSheetView } from 'expo-native-sheet-emojis';

function MyComponent() {
  return (
    <EmojiSheetView
      style={{ flex: 1 }}
      theme="light"
      onEmojiSelected={(emoji) => console.log(emoji)}
      columns={7}
      showSearch={true}
    />
  );
}
```

## Theming

Use the built-in presets or provide a full custom theme object:

```typescript
import { EmojiSheetModule, lightTheme, darkTheme } from 'expo-native-sheet-emojis';

// Preset themes
await EmojiSheetModule.present({ theme: 'dark' });
await EmojiSheetModule.present({ theme: lightTheme });

// Custom theme
await EmojiSheetModule.present({
  theme: {
    backgroundColor: '#1A1A2E',
    searchBarBackgroundColor: '#2A2F39',
    textColor: '#FFFFFF',
    textSecondaryColor: '#999999',
    accentColor: '#EA4578',
    dividerColor: '#3A3A4A',
  },
});
```

## Multilingual Search

English search keywords are always included (built into `emojis.json`). To enable search in additional languages, you need to bundle the corresponding locale files.

### Expo (managed or prebuild)

Configure the plugin in your `app.json` or `app.config.js`:

```json
{
  "plugins": [
    ["expo-native-sheet-emojis", { "searchLocales": ["es", "fr", "de", "ja"] }]
  ]
}
```

The config plugin copies only the selected locale files into your native bundles at prebuild time.

### Bare React Native (without Expo config plugins)

Manually copy the locale files you need from the package's `translations/` directory into your native projects:

**iOS:** Copy the desired `.json` files into your Xcode project, placing them alongside the module's `emojis.json`. The native code loads all `.json` files found in the `translations/` bundle directory.

```bash
# From your project root
cp node_modules/expo-native-sheet-emojis/translations/es.json ios/translations/
cp node_modules/expo-native-sheet-emojis/translations/fr.json ios/translations/
```

Make sure the `translations/` folder is added to your Xcode project as a folder reference and included in the "Copy Bundle Resources" build phase.

**Android:** Copy the files into your app's assets:

```bash
mkdir -p android/app/src/main/assets/translations
cp node_modules/expo-native-sheet-emojis/translations/es.json android/app/src/main/assets/translations/
cp node_modules/expo-native-sheet-emojis/translations/fr.json android/app/src/main/assets/translations/
```

### Supported Locales

`ca`, `cs`, `de`, `el`, `en`, `es`, `fi`, `fr`, `hi`, `hu`, `it`, `ja`, `ko`, `nl`, `pl`, `pt`, `ru`, `sv`, `tr`, `uk`, `zh`

**Bundle size impact:** The base emoji data (`emojis.json`) adds ~300KB to your app.
Each locale file adds 64-185KB depending on the language (all 21 locales total ~2.3MB). 
Only bundle the locales your app actually needs -- English-only apps pay zero extra since English keywords are already in the base data.
The config plugin ensures only selected locales are included in the native build.

### Custom Translations

You can create your own translation files for languages not included in the package, or override existing translations with custom keywords.

Each translation file is a JSON object mapping emoji characters to arrays of search keywords:

```json
{
  "\u2764\uFE0F": ["love", "heart", "red heart"],
  "\uD83D\uDE00": ["happy", "grin", "smile"],
  "\uD83D\uDC4D": ["thumbs up", "like", "approve"]
}
```

The keys are emoji characters (as Unicode strings) and the values are arrays of search keywords in your target language. The native search engine will match user input against these keywords.

**To add a custom translation:**

1. Create a `.json` file following the format above (e.g., `th.json` for Thai)
2. Place it in the native translations directory:
   - **iOS:** Add to the module's `translations/` bundle directory in Xcode
   - **Android:** Place in `android/app/src/main/assets/translations/`
3. The native code automatically picks up all `.json` files in the translations directory -- no code changes needed

**To generate a translation file from CLDR data:**

The package includes a maintainer script that generates translation files from Unicode CLDR annotation data:

```bash
cd node_modules/expo-native-sheet-emojis
yarn add --dev cldr-annotations-full
node scripts/build-emoji-translations.mjs
```

This produces per-locale files in `translations/` for all 21 supported languages. You can modify the `SUPPORTED_LOCALES` array in the script to add new languages that CLDR supports.

## API Reference

### EmojiSheetModule.present(options?)

Presents the emoji picker as a native bottom sheet. Returns a promise that resolves when the user selects an emoji or dismisses the sheet.

**Parameters:**

| Name | Type | Description |
|-|-|-|
| options | `EmojiSheetPresentOptions` | Optional configuration object |

**Returns:** `Promise<EmojiSheetResult>`

The result is a discriminated union:
- `{ emoji: string }` when an emoji is selected
- `{ cancelled: true }` when the sheet is dismissed without selection

### EmojiSheetModule.dismiss()

Programmatically dismisses the emoji picker sheet.

**Returns:** `Promise<void>`

### EmojiSheetView

A declarative React component that renders the emoji picker inline.

**Props:**

| Prop | Type | Default | Description |
|-|-|-|-|
| onEmojiSelected | `(emoji: string) => void` | required | Called when an emoji is tapped |
| theme | `EmojiSheetTheme \| 'dark' \| 'light'` | `'light'` | Theme configuration |
| translations | `EmojiSheetTranslations` | -- | Localized strings |
| categoryBarPosition | `'top' \| 'bottom'` | `'top'` | Position of the category tab bar |
| columns | `number` | `7` | Number of emoji columns in the grid |
| emojiSize | `number` | `32` | Size of each emoji cell in points |
| recentLimit | `number` | `30` | Maximum number of recently used emojis to track |
| showSearch | `boolean` | `true` | Whether to show the search bar |
| showRecents | `boolean` | `true` | Whether to show the frequently used section |
| enableSkinTones | `boolean` | `true` | Whether to enable skin tone selection on long press |
| excludeEmojis | `string[]` | `[]` | Array of emoji IDs to exclude (e.g., `["pile_of_poo", "thumbs_down"]`) |

### EmojiSheetTheme

All theme fields with their purpose:

| Field | Type | Required | Description |
|-|-|-|-|
| backgroundColor | `string` | yes | Main background color of the picker |
| searchBarBackgroundColor | `string` | yes | Background color of the search input |
| textColor | `string` | yes | Primary text color |
| textSecondaryColor | `string` | yes | Secondary/label text color |
| searchTextColor | `string` | no | Text color inside the search input |
| placeholderTextColor | `string` | no | Placeholder text color in search |
| accentColor | `string` | yes | Accent color for highlights and active states |
| selectionColor | `string` | no | Background color for selected emoji |
| categoryIconColor | `string` | no | Default color for category bar icons |
| categoryActiveIconColor | `string` | no | Color for the active category icon |
| categoryActiveBackgroundColor | `string` | no | Background behind the active category icon |
| handleColor | `string` | no | Color of the sheet drag handle |
| dividerColor | `string` | yes | Color for divider lines |
| categoryBarBackgroundColor | `string` | no | Background of the category bar area |

### EmojiSheetTranslations

| Field | Type | Description |
|-|-|-|
| searchPlaceholder | `string` | Placeholder text for the search input |
| noResultsText | `string` | Text shown when search yields no results |
| categoryNames | `Partial<Record<EmojiCategory, string>>` | Localized names for each category tab |

### EmojiSheetPresentOptions

| Field | Type | Default | Description |
|-|-|-|-|
| theme | `EmojiSheetTheme \| 'dark' \| 'light'` | `'light'` | Theme configuration |
| translations | `EmojiSheetTranslations` | -- | Localized UI strings |
| snapPoints | `[number, number]` | `[0.5, 1.0]` | Bottom sheet snap points as screen fractions |
| categoryBarPosition | `'top' \| 'bottom'` | `'top'` | Position of the category tab bar |
| columns | `number` | `7` | Number of columns in the emoji grid |
| emojiSize | `number` | `32` | Emoji cell size in points |
| recentLimit | `number` | `30` | Max frequently used emojis |
| showSearch | `boolean` | `true` | Show the search bar |
| showRecents | `boolean` | `true` | Show the frequently used section |
| enableSkinTones | `boolean` | `true` | Enable skin tone long-press |
| gestureEnabled | `boolean` | `true` | Allow swipe-to-dismiss gesture |
| backdropOpacity | `number` | `0.22` | Opacity of the backdrop behind the sheet |
| excludeEmojis | `string[]` | `[]` | Emoji IDs to hide from the picker |

### EmojiSheetResult

A discriminated union type:

```typescript
type EmojiSheetResult =
  | { emoji: string; cancelled?: never }
  | { cancelled: true; emoji?: never };
```

## Category Bar Position

The category bar can be placed at the **top** or **bottom** of the picker.

- **Top** (default): The category icons appear directly below the search bar. This mirrors the layout used by most native platform emoji keyboards.
- **Bottom**: The category icons float in a rounded pill at the bottom of the sheet with a blur backdrop (iOS) or elevated shadow (Android). This layout is familiar to users of chat applications like Slack and Discord.

Set via `categoryBarPosition: 'top'` or `categoryBarPosition: 'bottom'` in the options.

## Configuration Props

| Prop | Type | Default | Description |
|-|-|-|-|
| theme | `EmojiSheetTheme \| 'dark' \| 'light'` | `'light'` | Visual theme |
| translations | `EmojiSheetTranslations` | -- | Localized strings |
| snapPoints | `[number, number]` | `[0.5, 1.0]` | Sheet snap points |
| categoryBarPosition | `'top' \| 'bottom'` | `'top'` | Category bar placement |
| columns | `number` | `7` | Grid column count |
| emojiSize | `number` | `32` | Cell size (points) |
| recentLimit | `number` | `30` | Max recent emojis |
| showSearch | `boolean` | `true` | Show search bar |
| showRecents | `boolean` | `true` | Show recents section |
| enableSkinTones | `boolean` | `true` | Skin tone long-press |
| excludeEmojis | `string[]` | `[]` | Emoji IDs to exclude |
| gestureEnabled | `boolean` | `true` | Swipe to dismiss |
| backdropOpacity | `number` | `0.22` | Backdrop opacity |

## LLM / AI Agent Reference

If you're an AI agent or using an LLM to integrate this module, see [llms.txt](llms.txt) for a concise, structured reference with all types, APIs, and usage patterns.

## Contributing

Contributions are welcome! Please read the [contributing guide](CONTRIBUTING.md) before submitting a pull request.

## License

MIT
