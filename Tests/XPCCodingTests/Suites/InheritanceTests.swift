import Testing
import Foundation
import XPC
@testable import XPCCoding

// MARK: Inheritance Tests

@Suite("Inheritance", .tags(.inheritance))
struct InheritanceTests {

  // MARK: - Hierarchy Depth

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, exampleLevel0s()
  )
  func `Level0 rt ok`(
    configuration: XPCCodec.Configuration,
    probe: Level0
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, exampleLevel1s()
  )
  func `Level1 rt ok`(
    configuration: XPCCodec.Configuration,
    probe: Level1
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, exampleLevel2s()
  )
  func `Level2 rt ok`(
    configuration: XPCCodec.Configuration,
    probe: Level2
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, exampleLevel3s()
  )
  func `Level3 rt ok`(
    configuration: XPCCodec.Configuration,
    probe: Level3
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, exampleLevel4s()
  )
  func `Level4 rt ok`(
    configuration: XPCCodec.Configuration,
    probe: Level4
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, exampleLevel5s()
  )
  func `Level5 rt ok`(
    configuration: XPCCodec.Configuration,
    probe: Level5
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, exampleLevel6s()
  )
  func `Level6 rt ok`(
    configuration: XPCCodec.Configuration,
    probe: Level6
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  // MARK: - Shared Encoder Pattern Tests

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, exampleSharedEncoderBases()
  )
  func `SharedEncoderBase rt ok`(
    configuration: XPCCodec.Configuration,
    probe: SharedEncoderBase
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, exampleSharedEncoderChildren()
  )
  func `SharedEncoderChild rt ok`(
    configuration: XPCCodec.Configuration,
    probe: SharedEncoderChild
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  // MARK: - Custom "Super" Key

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, exampleCustomSuperKeys()
  )
  func `CustomSuperKey rt ok`(
    configuration: XPCCodec.Configuration,
    probe: CustomSuperKey
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  // MARK: - Inheritance w/Optionals

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, exampleOptionalBases()
  )
  func `OptionalBase rt ok`(
    configuration: XPCCodec.Configuration,
    probe: OptionalBase
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, exampleOptionalChildren()
  )
  func `OptionalChild rt ok`(
    configuration: XPCCodec.Configuration,
    probe: OptionalChild
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  // MARK: - Inheritance w/Mixed Types

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, exampleMixedTypeBase()
  )
  func `MixedTypeBase rt ok`(
    configuration: XPCCodec.Configuration,
    probe: MixedTypeBase
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

  @Test(
    .tags(.roundTrip),
    arguments: XPCCodec.Configuration.allCases, exampleMixedTypeChildren()
  )
  func `MixedTypeBase rt ok`(
    configuration: XPCCodec.Configuration,
    probe: MixedTypeChild
  ) throws {
    try verifyRoundTrip(
      ofValueAndWrappers: probe,
      configuration: configuration
    )
  }

}
