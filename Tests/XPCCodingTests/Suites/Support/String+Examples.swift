// Embedded-null probes deliberately live in `EmbeddedNullStringProbe.swift`,
// not here: they carry expected-truncation data and a null-free label, which a
// bare `[String]` cannot.
extension String {

  static let unicodeExamples: [Self] = [
    "Hello 🌍",
    "🎉🎊🎈🎁",
    "🇺🇸🇬🇧🇯🇵🇩🇪🇫🇷",
    "👋🏻👋🏽👋🏿",
    "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}",
  ]

  static let rtlExamples: [Self] = [
    // Arabic
    "مرحبا",

    // Hebrew
    "שלום",

    // Mixed RTL and LTR
    "Hello مرحبا World",
  ]

  static let cjkExamples: [Self] = [
    "你好",
    "こんにちは",
    "안녕하세요",
  ]

  static let combiningExamples: [Self] = [
    // é (e + combining acute accent)
    "e\u{0301}",

    // Multiple combining marks
    "e\u{0301}\u{0302}\u{0308}",

    // Decomposed text
    "café",
    "cafe\u{0301}",
  ]

  static let newlineAndTabExamples: [Self] = [
    "Line1\nLine2",
    "Line1\r\nLine2",
    "Tab\there",
  ]

}
