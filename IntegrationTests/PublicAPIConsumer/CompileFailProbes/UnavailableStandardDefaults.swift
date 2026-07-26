import XPCCoding

// Issue #30 moves these forms into the permanent green consumer after making
// the complete standard/default surface public and mutually consistent.
let encoderKeyStrategy: XPCEncoder.StringKeyStrategy = .standard
let encoderValueStrategy: XPCEncoder.StringValueStrategy = .standard
let configuration: XPCCodec.Configuration = .standard
let codec = XPCCodec()
let standardCodec = XPCCodec.standard
