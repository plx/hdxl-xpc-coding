import Foundation

public enum XPCIntegrationProtocol {

  public static let clientBundleIdentifier =
    "com.plx.hdxl-xpc-coding.integration.client"
  public static let serviceBundleIdentifier =
    "com.plx.hdxl-xpc-coding.integration.service"

  public enum Key {
    public static let operation = "operation"
    public static let clientPID = "client-pid"
    public static let servicePID = "service-pid"
    public static let status = "status"
    public static let errorCode = "error-code"
    public static let errorDetail = "error-detail"
    public static let observations = "observations"
    public static let dataChecksum = "data-checksum"

    public static let scalar = "scalar-root"
    public static let array = "array-root"
    public static let keyed = "keyed-root"
    public static let nested = "nested-root"
    public static let repairedString = "repaired-string-root"
    public static let signedNarrow = "signed-narrow-root"
    public static let unsignedNarrow = "unsigned-narrow-root"
    public static let floatingPoint = "floating-point-root"
    public static let integer128 = "integer-128-root"
    public static let data = "data-root"
  }

  public enum Operation {
    public static let exercise = "exercise"
    public static let terminateWithoutReply = "terminate-without-reply"
  }

  public enum Status {
    public static let success = "success"
    public static let error = "error"
  }

  public enum ErrorCode {
    public static let invalidApplicationMessage =
      "invalid-application-message"
  }

  public enum Shape {
    public static let int64 = "int64"
    public static let uint64 = "uint64"
    public static let double = "double"
    public static let string = "string"
    public static let data = "data"
    public static let array = "array"
    public static let dictionary = "dictionary"
  }

  public static let largeDataCount = 1_048_576

}

public struct IntegrationKeyedPayload: Codable, Equatable, Sendable {

  public let label: String
  public let count: Int

  public init(
    label: String,
    count: Int
  ) {
    self.label = label
    self.count = count
  }

}

public struct IntegrationNestedPayload: Codable, Equatable, Sendable {

  public let name: String
  public let child: Child

  public init(
    name: String,
    child: Child
  ) {
    self.name = name
    self.child = child
  }

  public struct Child: Codable, Equatable, Sendable {

    public let enabled: Bool
    public let values: [Int]

    public init(
      enabled: Bool,
      values: [Int]
    ) {
      self.enabled = enabled
      self.values = values
    }

  }

}

public func integrationDataChecksum(_ data: Data) -> UInt64 {
  data.reduce(14_695_981_039_346_656_037) { partialResult, byte in
    (partialResult ^ UInt64(byte)) &* 1_099_511_628_211
  }
}
