import Benchmark
import Foundation
import XPC
import XPCCoding

// MARK: - Benchmark Entry Point

let benchmarks: @Sendable () -> Void = {
  // Simulated IPC roundtrip benchmarks
  // These measure the complete encode/decode cycle that would occur in IPC
  simulatedIPCRoundtripBenchmarks()

  // Complex command/response benchmarks
  complexIPCBenchmarks()
}

// MARK: - Simulated IPC Roundtrip Benchmarks

/// Simulates a complete IPC roundtrip:
/// 1. Client encodes request
/// 2. Server decodes request
/// 3. Server encodes response
/// 4. Client decodes response
///
/// This measures the total encoding/decoding overhead in a typical IPC scenario.
/// Note: This does not include actual XPC transport overhead, which would require
/// setting up named XPC services (typically done in an Xcode project context).
private func simulatedIPCRoundtripBenchmarks() {
  for size in MessageSize.allCases {
    let request = BenchmarkRequest.example(payloadSize: size.payloadSize)

    // XPC strategy: direct encode/decode using XPCCoding
    Benchmark("IPC.simulated.\(size.rawValue).xpc") { _ in
      let xpcEncoder = XPCEncoder()
      let xpcDecoder = XPCDecoder()

      // Client side: encode request
      let encodedRequest = try xpcEncoder.encode(request)

      // Server side: decode request, create response, encode response
      let decodedRequest = try xpcDecoder.decode(BenchmarkRequest.self, from: encodedRequest)
      let response = BenchmarkResponse.forRequest(decodedRequest, resultSize: size.payloadSize)
      let encodedResponse = try xpcEncoder.encode(response)

      // Client side: decode response
      blackHole(try xpcDecoder.decode(BenchmarkResponse.self, from: encodedResponse))
    }

    // JSON strategy: encode to JSON Data, which could be transmitted as XPC data
    Benchmark("IPC.simulated.\(size.rawValue).json") { _ in
      let jsonEncoder = JSONEncoder()
      let jsonDecoder = JSONDecoder()

      // Client side: encode request to JSON
      let jsonRequest = try jsonEncoder.encode(request)

      // Server side: decode request, create response, encode response
      let decodedRequest = try jsonDecoder.decode(BenchmarkRequest.self, from: jsonRequest)
      let response = BenchmarkResponse.forRequest(decodedRequest, resultSize: size.payloadSize)
      let jsonResponse = try jsonEncoder.encode(response)

      // Client side: decode response
      blackHole(try jsonDecoder.decode(BenchmarkResponse.self, from: jsonResponse))
    }
  }
}

// MARK: - Complex IPC Benchmarks

/// Benchmarks using more complex, realistic IPC message types.
private func complexIPCBenchmarks() {
  // Ping command (minimal overhead)
  let pingCommand = IPCCommand.pingCommand()

  Benchmark("IPC.complex.ping.xpc") { _ in
    let xpcEncoder = XPCEncoder()
    let xpcDecoder = XPCDecoder()

    let encodedCmd = try xpcEncoder.encode(pingCommand)
    let decodedCmd = try xpcDecoder.decode(IPCCommand.self, from: encodedCmd)
    let response = IPCResponse.successResponse(for: decodedCmd, resultSize: 0)
    let encodedResp = try xpcEncoder.encode(response)
    blackHole(try xpcDecoder.decode(IPCResponse.self, from: encodedResp))
  }

  Benchmark("IPC.complex.ping.json") { _ in
    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()

    let encodedCmd = try jsonEncoder.encode(pingCommand)
    let decodedCmd = try jsonDecoder.decode(IPCCommand.self, from: encodedCmd)
    let response = IPCResponse.successResponse(for: decodedCmd, resultSize: 0)
    let encodedResp = try jsonEncoder.encode(response)
    blackHole(try jsonDecoder.decode(IPCResponse.self, from: encodedResp))
  }

  // Query command with data
  for size in [MessageSize.small, MessageSize.medium, MessageSize.large] {
    let queryCommand = IPCCommand.queryCommand(withDataSize: size.payloadSize)

    Benchmark("IPC.complex.query.\(size.rawValue).xpc") { _ in
      let xpcEncoder = XPCEncoder()
      let xpcDecoder = XPCDecoder()

      let encodedCmd = try xpcEncoder.encode(queryCommand)
      let decodedCmd = try xpcDecoder.decode(IPCCommand.self, from: encodedCmd)
      let response = IPCResponse.successResponse(for: decodedCmd, resultSize: size.payloadSize)
      let encodedResp = try xpcEncoder.encode(response)
      blackHole(try xpcDecoder.decode(IPCResponse.self, from: encodedResp))
    }

    Benchmark("IPC.complex.query.\(size.rawValue).json") { _ in
      let jsonEncoder = JSONEncoder()
      let jsonDecoder = JSONDecoder()

      let encodedCmd = try jsonEncoder.encode(queryCommand)
      let decodedCmd = try jsonDecoder.decode(IPCCommand.self, from: encodedCmd)
      let response = IPCResponse.successResponse(for: decodedCmd, resultSize: size.payloadSize)
      let encodedResp = try jsonEncoder.encode(response)
      blackHole(try jsonDecoder.decode(IPCResponse.self, from: encodedResp))
    }
  }
}

// MARK: - Notes on True IPC Benchmarks

/*
 True cross-process XPC benchmarks require setting up named XPC services,
 which typically involves:

 1. Creating an XPC service target in an Xcode project
 2. Configuring the service's Info.plist with a bundle identifier
 3. Embedding the service in a host application
 4. Using xpc_connection_create_mach_service() to connect

 For documentation purposes, the simulated benchmarks above measure the
 encoding/decoding overhead, which is the primary differentiator between
 using XPCCoding directly vs JSON-over-XPC.

 The actual XPC transport overhead (mach message passing) is identical
 regardless of the encoding strategy used, since both ultimately send
 xpc_object_t values over the connection.

 Key insight: XPCCoding's advantage comes from:
 1. Native xpc_object_t output - no additional wrapping needed
 2. Direct binary data support - no base64 encoding overhead
 3. Type-appropriate XPC primitives - integers stay integers, not strings
 */
