#if os(iOS) && !targetEnvironment(macCatalyst)
  #error("Deliberate failure proving that CI rejects an iOS compile error.")
#endif
