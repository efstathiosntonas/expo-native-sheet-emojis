Pod::Spec.new do |s|
  s.name           = 'EmojiSheetModule'
  s.version        = '1.2.0'
  s.summary        = 'Native emoji picker bottom sheet for React Native'
  s.description    = 'A fully native iOS/Android emoji picker presented in a bottom sheet with search, skin tones, and theming support.'
  s.author         = ''
  s.homepage       = 'https://github.com/efstathiosntonas/expo-native-sheet-emojis'
  s.license        = { type: 'MIT' }
  s.platforms      = { ios: '15.1' }
  s.source         = { git: '' }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.source_files = "**/*.{h,m,mm,swift,hpp,cpp}"
  s.resources = ["emojis.json", "translations/*.json"]
end
