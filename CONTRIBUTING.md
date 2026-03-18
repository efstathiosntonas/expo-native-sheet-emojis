# Contributing

Thanks for your interest in contributing to expo-native-sheet-emojis! Pull requests are welcome.

## Getting Started

1. Fork and clone the repository
2. Install dependencies: `yarn install`
3. Set up the example app:
   ```bash
   cd example
   yarn install
   npx expo prebuild --clean
   npx expo run:ios   # or run:android
   ```
4. Make your changes in the `src/`, `ios/`, or `android/` directories
5. Test on both platforms before submitting

## Commit Convention

This project follows [Conventional Commits](https://www.conventionalcommits.org/). All commit messages must follow this format:

```
<type>(<scope>): <description>

[optional body]
```

Lefthook enforces this automatically on commit.

### Types

| Type | Description |
|-|-|
| feat | A new feature |
| fix | A bug fix |
| docs | Documentation changes |
| style | Code style changes (formatting, no logic change) |
| refactor | Code refactoring (no feature or bug fix) |
| perf | Performance improvements |
| test | Adding or updating tests |
| chore | Build process, tooling, or dependency updates |

### Examples

```
feat(ios): add haptic feedback on emoji selection
fix(android): resolve search bar focus crash on API 28
docs: update theming guide with custom color examples
chore: bump expo-modules-core to 55.0.20
```

## Pull Request Guidelines

- Keep PRs focused on a single change
- Include a clear description of what changed and why
- Test on both iOS and Android
- Follow the existing code style
- Update the README if your change affects the public API
- Add yourself to the contributors list if you'd like

## Pre-commit Hooks

This project uses [Lefthook](https://github.com/evilmartians/lefthook) for git hooks. They are installed automatically on `yarn install`. The hooks run:

- **pre-commit**: ESLint, Prettier check, and TypeScript typecheck on staged files
- **commit-msg**: Conventional commit format validation

## Project Structure

```
src/           TypeScript layer (module, types, view, themes)
ios/           Swift native code (UIKit)
android/       Kotlin native code
plugin/        Expo config plugin (locale file copying)
translations/  Per-locale search keyword files (generated from CLDR)
scripts/       Maintainer scripts for emoji data generation
example/       Expo example app for development
```

## Native Development

- **iOS**: Swift, UIKit, UICollectionViewCompositionalLayout
- **Android**: Kotlin, RecyclerView, BottomSheetDialog

Both platforms use the Expo Modules API for bridging. The module name is `EmojiSheet` and the internal class prefix is `EmojiSheet*`.

## Running the Example

The example app is a full Expo SDK 55 project. It requires a native build (not Expo Go) since this is a native module:

```bash
cd example
yarn install
npx expo prebuild --clean
npx expo run:ios
# or
npx expo run:android
```

## Generating Translation Files

Translation files are generated from Unicode CLDR annotation data:

```bash
yarn add --dev cldr-annotations-full
node scripts/build-emoji-translations.mjs
```

This produces per-locale JSON files in `translations/`.

## Questions?

Open an issue on GitHub for bugs, feature requests, or questions.
