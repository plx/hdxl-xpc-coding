# XPC Coding Test Suite Expansion Plan

## Executive Summary

This document outlines a comprehensive plan to expand the test coverage for the `XPCCoding` Swift package. The current test suite (`CodableXPCTests.swift`, ~530 lines) provides basic round-trip verification but has significant gaps in coverage for edge cases, primitive types, container variations, inheritance depth, and error conditions.

The new test suite will:
1. Migrate to Swift Testing framework (replacing XCTest)
2. Use data-driven/parameterized tests where applicable
3. Organize tests into logical suites with tags for filtering
4. Significantly expand coverage depth and breadth

---

## Analysis of Existing Tests

### Current Test Inventory

| Test Name | What It Verifies | Gaps |
|-----------|------------------|------|
| `testEncodingTopLevelEmptyStruct` | Empty struct round-trips | Only one empty struct |
| `testEncodingTopLevelEmptyClass` | Empty class round-trips | Bug: `EmptyClass` is actually a struct |
| `testEncodingTopLevelSingleValueEnum` | Enum → Bool via single-value container | Only Bool encoding |
| `testEncodingTopLevelSingleValueStruct` | Struct → Double via single-value container | Only Double |
| `testEncodingTopLevelSingleValueClass` | Class → Int via single-value container | Only Int |
| `testEncodingTopLevelStructuredStruct` | Multi-field struct (Address) | No edge cases |
| `testEncodingTopLevelStructuredClass` | Multi-field class (Person) with Optional | No deep optionals |
| `testEncodingTopLevelStructuredSingleStruct` | Struct → Array via single-value | Fixed values only |
| `testEncodingTopLevelStructuredSingleClass` | Class → Dictionary via single-value | Small dictionary |
| `testEncodingDerivedClass` | 1-level inheritance with superEncoder | Only depth 1 |
| `testEncodingClassWhichSharesEncoderWithSuper` | Inheritance sharing encoder | Only depth 1 |
| `testEncodingTopLevelDeepStructuredType` | Nested structs/arrays (Company) | Only one nesting pattern |
| `testEncodingTopLevelNullableType` | Nil encoding via single-value | Only Bool? equivalent |
| `testEncodingDictionaryFailureKeyPath` | CodingPath on encode error | Only 1 level |
| `testEncodingDictionaryFailureKeyPathNested` | CodingPath on nested encode error | Only 2 levels |
| `testDecodingDictionaryFailureKeyPath` | CodingPath on decode error | Only 1 level |
| `testDecodingDictionaryFailureKeyPathNested` | CodingPath on nested decode error | Only 2 levels |

### Identified Gaps

1. **No primitive type coverage**: Individual encoding/decoding of Bool, Int8-64, UInt8-64, Float16/32/64, String, Data
2. **No edge case testing**: Min/max values, empty strings, NaN/Infinity, special Unicode
3. **No unkeyed container tests**: Direct array encoding without wrapper types
4. **Shallow inheritance**: Only 1 level tested (should test 2-6 levels)
5. **Limited optional handling**: `encodeIfPresent`/`decodeIfPresent` not exercised
6. **No nested container tests**: `nestedContainer(keyedBy:)` and `nestedUnkeyedContainer(forKey:)` not tested
7. **Missing collection types**: Empty arrays, nested arrays, heterogeneous dictionaries
8. **No standard library types**: UUID, Date (via TimeInterval), URL edge cases
9. **Error condition gaps**: Many error paths never exercised
10. **No XPCDecoder validation tests**: Constructor rejection of non-dictionaries

---

## New Test Suite Architecture

### File Organization

```
Tests/XPCCodingTests/
├── Suites/
│   ├── PrimitiveTypeTests.swift          # All primitive type encoding/decoding
│   ├── KeyedContainerTests.swift         # Dictionary/keyed container operations
│   ├── UnkeyedContainerTests.swift       # Array/unkeyed container operations
│   ├── SingleValueContainerTests.swift   # Single-value container operations
│   ├── InheritanceTests.swift            # Class inheritance at various depths
│   ├── NestedContainerTests.swift        # Nested keyed/unkeyed containers
│   ├── OptionalAndNilTests.swift         # Optional handling, nil encoding
│   ├── CollectionTests.swift             # Arrays, dictionaries, sets
│   ├── StandardLibraryTypeTests.swift    # URL, UUID, Date, etc.
│   ├── ErrorConditionTests.swift         # All error paths and conditions
│   ├── CodingPathTests.swift             # CodingPath tracking verification
│   └── EdgeCaseTests.swift               # Boundary conditions, special values
├── Support/
│   ├── TestTypes.swift                   # Shared test type definitions
│   ├── TestHelpers.swift                 # Shared test utilities
│   └── TestTags.swift                    # Tag definitions for test filtering
└── LegacyTests/
    └── CodableXPCTests.swift             # Original tests (can be removed after migration)
```

### Tag System

```swift
// TestTags.swift
extension Tag {
  @Tag static var encoding: Self
  @Tag static var decoding: Self
  @Tag static var roundTrip: Self
  @Tag static var primitives: Self
  @Tag static var containers: Self
  @Tag static var keyed: Self
  @Tag static var unkeyed: Self
  @Tag static var singleValue: Self
  @Tag static var inheritance: Self
  @Tag static var optionals: Self
  @Tag static var errors: Self
  @Tag static var edgeCases: Self
  @Tag static var collections: Self
  @Tag static var standardLibrary: Self
  @Tag static var codingPath: Self
}
```

---

## Detailed Test Suite Specifications

### Suite 1: PrimitiveTypeTests.swift

**Purpose**: Verify encoding and decoding of all primitive types supported by the XPC type system.

**File Name**: `Tests/XPCCodingTests/Suites/PrimitiveTypeTests.swift`

**Capabilities Being Verified**:
- Each primitive type can be encoded to XPC and decoded back correctly
- Edge values (min, max, zero, special) are handled correctly
- XPC type mapping is correct (e.g., Int8-32 → XPC_TYPE_DATA, Int64 → XPC_TYPE_INT64)

**Test Cases**:

#### 1.1 Boolean Tests
```
@Test(.tags(.primitives, .roundTrip))
func booleanRoundTrip() { /* true, false */ }
```

#### 1.2 Signed Integer Tests (Parameterized)
```
Types: Int8, Int16, Int32, Int64, Int
Values per type: .min, -1, 0, 1, .max
```
- Verify round-trip for each value
- Verify XPC type mapping (Int8/16/32 → DATA, Int64/Int → INT64)

#### 1.3 Unsigned Integer Tests (Parameterized)
```
Types: UInt8, UInt16, UInt32, UInt64, UInt
Values per type: 0, 1, .max, .max/2
```
- Verify round-trip for each value
- Verify XPC type mapping (UInt8/16/32 → DATA, UInt64/UInt → UINT64)

#### 1.4 Floating Point Tests (Parameterized)
```
Types: Float16, Float, Double
Values: 0.0, -0.0, 1.0, -1.0, .pi, .infinity, -.infinity, .nan, .leastNormalMagnitude, .greatestFiniteMagnitude
```
- Verify round-trip (with special NaN handling)
- Verify XPC type mapping (Float16/Float → DATA, Double → DOUBLE)

#### 1.5 String Tests
```
Values: "", "a", "Hello, World!", Unicode strings (emoji, CJK, RTL), very long strings (1MB), null bytes
```

#### 1.6 Data Tests
```
Values: empty Data, small Data, large Data (1MB), Data with all byte values 0-255
```

**Verification Approach**:
- Use `@Test(arguments:)` for parameterized testing
- Wrap primitive in a single-property struct for keyed container testing
- Also test via single-value container directly
- Assert encoded XPC type matches expectation
- Assert decoded value equals original (special handling for NaN)

**Implementation Notes**:
- Create a `PrimitiveWrapper<T: Codable & Equatable>` struct for keyed encoding
- Use `withKnownIssue` for any known limitations
- Consider separate tests for each container type (keyed vs single-value)

---

### Suite 2: KeyedContainerTests.swift

**Purpose**: Verify all `KeyedEncodingContainer` and `KeyedDecodingContainer` operations.

**File Name**: `Tests/XPCCodingTests/Suites/KeyedContainerTests.swift`

**Capabilities Being Verified**:
- All `encode(_:forKey:)` overloads for each primitive type
- `encodeNil(forKey:)` creates XPC_TYPE_NULL
- `encodeIfPresent(_:forKey:)` for optional values
- `nestedContainer(keyedBy:forKey:)` creates nested dictionaries
- `nestedUnkeyedContainer(forKey:)` creates nested arrays
- `superEncoder()` and `superEncoder(forKey:)` for inheritance
- `allKeys` returns correct keys
- `contains(_:)` correctly identifies present/absent keys
- `decodeNil(forKey:)` correctly identifies null values
- `decodeIfPresent(_:forKey:)` returns nil for missing keys

**Test Cases**:

#### 2.1 Basic Keyed Encoding
- Encode struct with one field of each primitive type
- Verify XPC dictionary structure matches expected keys

#### 2.2 Empty Dictionary
- Encode empty struct
- Verify creates empty XPC dictionary

#### 2.3 Nil Encoding in Keyed Container
```
struct WithNil: Codable { var value: String? }
```
- Test with value present vs nil
- Verify XPC_TYPE_NULL for nil case

#### 2.4 encodeIfPresent Variations
- Test each overload: Bool, Int, String, Double, etc.
- Verify key absent when value is nil

#### 2.5 Nested Keyed Container
```
struct Outer {
  func encode(to encoder: Encoder) {
    var container = encoder.container(keyedBy: CodingKeys.self)
    var nested = container.nestedContainer(keyedBy: InnerKeys.self, forKey: .inner)
    try nested.encode("value", forKey: .field)
  }
}
```
- Verify nested XPC dictionary structure

#### 2.6 Nested Unkeyed Container in Keyed
```
struct WithArray {
  func encode(to encoder: Encoder) {
    var container = encoder.container(keyedBy: CodingKeys.self)
    var nested = container.nestedUnkeyedContainer(forKey: .items)
    for item in items { try nested.encode(item) }
  }
}
```

#### 2.7 allKeys Verification
- Decode dictionary with known keys
- Verify `allKeys` returns all and only those keys

#### 2.8 contains(_:) Verification
- Test with present key → true
- Test with absent key → false

**Verification Approach**:
- Mix of round-trip tests and direct XPC structure verification
- Use `xpc_dictionary_apply` to verify dictionary contents
- Create custom Codable types with explicit encode/decode implementations

---

### Suite 3: UnkeyedContainerTests.swift

**Purpose**: Verify all `UnkeyedEncodingContainer` and `UnkeyedDecodingContainer` operations.

**File Name**: `Tests/XPCCodingTests/Suites/UnkeyedContainerTests.swift`

**Capabilities Being Verified**:
- All `encode(_:)` overloads for primitives
- `encodeNil()` appends XPC_TYPE_NULL
- `count` property tracks elements correctly
- `nestedContainer(keyedBy:)` creates nested dictionary in array
- `nestedUnkeyedContainer()` creates nested array in array
- `superEncoder()` for inheritance in array context
- `isAtEnd` correctly indicates array exhaustion
- `currentIndex` tracks position during decoding
- `decodeNil()` correctly identifies and advances past null

**Test Cases**:

#### 3.1 Empty Array
- Encode type that produces empty array
- Verify `xpc_array_get_count` returns 0

#### 3.2 Homogeneous Primitive Arrays (Parameterized)
```
Types: [Bool], [Int], [String], [Double], etc.
Sizes: 0, 1, 10, 1000
```

#### 3.3 Heterogeneous Arrays via Codable
```
struct MixedContainer: Codable {
  // Uses single-value container to encode array with mixed Codable elements
}
```

#### 3.4 Array with Nil Elements
```
[Optional<String>] with some nil values
```
- Verify XPC_TYPE_NULL at correct indices

#### 3.5 Nested Arrays
```
[[Int]], [[[String]]], etc. up to depth 5
```

#### 3.6 Array of Dictionaries
```
[struct with fields] as [[String: Any]]
```

#### 3.7 Nested Keyed Container in Unkeyed
- Manual encode using `nestedContainer(keyedBy:)`
- Verify XPC dictionary appears at correct array index

#### 3.8 count and isAtEnd Tracking
- Decode array and verify `count` matches
- Verify `isAtEnd` is false until all consumed, then true
- Verify `currentIndex` increments correctly

#### 3.9 superEncoder in Unkeyed Context
- Test class inheritance where parent is encoded via unkeyed container

**Verification Approach**:
- Use wrapper structs with custom Codable implementations
- Verify XPC array structure with `xpc_array_get_count` and `xpc_array_get_value`
- Test both encoding and decoding paths explicitly

---

### Suite 4: SingleValueContainerTests.swift

**Purpose**: Verify `SingleValueEncodingContainer` and `SingleValueDecodingContainer` operations.

**File Name**: `Tests/XPCCodingTests/Suites/SingleValueContainerTests.swift`

**Capabilities Being Verified**:
- Encoding a single primitive value as the top-level result
- Encoding nil as XPC_TYPE_NULL
- Encoding complex types (arrays, dictionaries) via single-value container
- Decoding single values correctly
- `decodeNil()` correctly identifies null

**Test Cases**:

#### 4.1 Single Primitive Values (Parameterized)
```
Types: Bool, Int, String, Double, etc.
```
- Encode via `singleValueContainer().encode(_:)`
- Verify XPC object type matches expected

#### 4.2 Single Nil Value
```
struct NilWrapper: Codable {
  func encode(to encoder: Encoder) {
    var container = encoder.singleValueContainer()
    try container.encodeNil()
  }
}
```
- Verify XPC_TYPE_NULL

#### 4.3 Array via Single-Value Container
```
struct ArrayWrapper: Codable {
  let items: [Int]
  func encode(to encoder: Encoder) {
    var container = encoder.singleValueContainer()
    try container.encode(items)
  }
}
```
- Verify XPC array structure

#### 4.4 Dictionary via Single-Value Container
```
struct DictWrapper: Codable {
  let mapping: [String: Int]
  func encode(to encoder: Encoder) {
    var container = encoder.singleValueContainer()
    try container.encode(mapping)
  }
}
```
- Verify XPC dictionary structure

#### 4.5 Complex Nested Type via Single-Value
- Encode struct with nested types via single-value container
- Verify full structure preserved

**Verification Approach**:
- Create wrapper types with explicit single-value encoding
- Verify top-level XPC object type
- Round-trip testing for decoding

---

### Suite 5: InheritanceTests.swift

**Purpose**: Verify class inheritance encoding/decoding at various depths using both `superEncoder()` and shared encoder patterns.

**File Name**: `Tests/XPCCodingTests/Suites/InheritanceTests.swift`

**Capabilities Being Verified**:
- Single-level inheritance (class → subclass)
- Multi-level inheritance (depth 2, 3, 4, 5, 6)
- `superEncoder()` creates proper nested structure
- `superDecoder()` retrieves nested structure
- Shared encoder pattern (subclass encodes to same container as parent)
- `superEncoder(forKey:)` with custom key
- `superDecoder(forKey:)` with custom key
- Inheritance in unkeyed container context

**Test Cases**:

#### 5.1 Depth 1: Base → Child
```
class Level0 { var a: Int }
class Level1: Level0 { var b: Int }
```
- Test with `superEncoder()`
- Test with shared encoder

#### 5.2 Depth 2: Base → Child → Grandchild
```
class Level0 { var a: Int }
class Level1: Level0 { var b: Int }
class Level2: Level1 { var c: Int }
```

#### 5.3 Depth 3-6 (Parameterized)
- Generate class hierarchies programmatically or define them
- Verify all properties preserved through round-trip

#### 5.4 Custom Super Key
```
try container.encode(value, forKey: .parent)
try super.encode(to: container.superEncoder(forKey: .parent))
```

#### 5.5 Inheritance with Optional Properties
- Mix required and optional properties at each level

#### 5.6 Inheritance in Unkeyed Context
```
class BaseInArray: Codable { ... }
class ChildInArray: BaseInArray { ... }
// Encode [ChildInArray]
```

#### 5.7 Mixed Inheritance Patterns
- Some levels use `superEncoder()`, others share encoder

**Verification Approach**:
- Create class hierarchies at compile time (Swift doesn't support runtime class generation)
- Use factory pattern to generate test instances
- Verify all properties at all levels after round-trip
- Verify XPC structure has correct nesting (nested "super" dictionaries)

**Implementation Notes**:
- May need to manually define Level0 through Level6 classes
- Consider using protocol with associated type for reusable test logic

---

### Suite 6: NestedContainerTests.swift

**Purpose**: Verify nested container creation and usage patterns.

**File Name**: `Tests/XPCCodingTests/Suites/NestedContainerTests.swift`

**Capabilities Being Verified**:
- `nestedContainer(keyedBy:forKey:)` on keyed container
- `nestedUnkeyedContainer(forKey:)` on keyed container
- `nestedContainer(keyedBy:)` on unkeyed container
- `nestedUnkeyedContainer()` on unkeyed container
- Deep nesting (5+ levels)
- Mixed nesting patterns (keyed → unkeyed → keyed → ...)

**Test Cases**:

#### 6.1 Keyed in Keyed (depth 2-5)
```
{ "outer": { "inner": { "deep": { ... } } } }
```

#### 6.2 Unkeyed in Keyed
```
{ "items": [1, 2, 3] }
```

#### 6.3 Keyed in Unkeyed
```
[ { "name": "first" }, { "name": "second" } ]
```

#### 6.4 Unkeyed in Unkeyed
```
[ [1, 2], [3, 4], [5, 6] ]
```

#### 6.5 Alternating Pattern (depth 6)
```
{ "a": [ { "b": [ { "c": 42 } ] } ] }
```

#### 6.6 Wide Nesting
- Single level with many nested containers (100 keys, each with nested container)

**Verification Approach**:
- Custom Codable types with explicit nested container usage
- Verify XPC structure matches expected shape
- Round-trip testing

---

### Suite 7: OptionalAndNilTests.swift

**Purpose**: Verify all optional and nil handling patterns.

**File Name**: `Tests/XPCCodingTests/Suites/OptionalAndNilTests.swift`

**Capabilities Being Verified**:
- `encodeNil(forKey:)` in keyed container
- `encodeIfPresent(_:forKey:)` all overloads
- `encodeNil()` in unkeyed container
- `encodeNil()` in single-value container
- `decodeNil(forKey:)` in keyed container
- `decodeIfPresent(_:forKey:)` all overloads
- `decodeNil()` in unkeyed container
- `decodeNil()` in single-value container
- Nested optionals (Optional<Optional<T>>)

**Test Cases**:

#### 7.1 Optional Property Present
```
struct S { var x: Int? = 42 }
```
- Verify value encoded, not null

#### 7.2 Optional Property Nil
```
struct S { var x: Int? = nil }
```
- Verify XPC_TYPE_NULL or key absent (depending on encoding strategy)

#### 7.3 encodeIfPresent - All Types (Parameterized)
- Bool?, Int?, String?, Double?, etc.
- Test with value and without

#### 7.4 Explicit encodeNil
```
try container.encodeNil(forKey: .field)
```
- Verify XPC_TYPE_NULL at that key

#### 7.5 Nil in Array
```
[String?] = ["a", nil, "b"]
```
- Verify XPC_TYPE_NULL at index 1

#### 7.6 Nested Optionals
```
struct S { var x: Int?? }
```
- Verify correct encoding of .some(.some(v)), .some(.none), .none

#### 7.7 decodeIfPresent for Missing Key
- Decode from dictionary without the key
- Verify returns nil, doesn't throw

#### 7.8 decodeNil() Advances Index
- In unkeyed container, verify decodeNil() on null advances currentIndex

**Verification Approach**:
- Explicit XPC structure verification with `xpc_get_type`
- Round-trip testing
- Direct container method testing

---

### Suite 8: CollectionTests.swift

**Purpose**: Verify encoding/decoding of collection types.

**File Name**: `Tests/XPCCodingTests/Suites/CollectionTests.swift`

**Capabilities Being Verified**:
- Array encoding as XPC_TYPE_ARRAY
- Dictionary encoding as XPC_TYPE_DICTIONARY
- Set encoding (via Array)
- Empty collections
- Large collections
- Collections with complex element types

**Test Cases**:

#### 8.1 Array of Primitives (Parameterized)
```
[Bool], [Int], [String], [Double], [Data]
Sizes: 0, 1, 10, 1000
```

#### 8.2 Array of Codable Structs
```
[Address] with varying sizes
```

#### 8.3 Dictionary with String Keys
```
[String: Int], [String: String], [String: Codable]
```

#### 8.4 Dictionary with Int Keys (via CodingKey)
```
[Int: String] - Note: requires custom CodingKey handling
```

#### 8.5 Set Encoding
```
Set<Int>, Set<String>
```
- Verify encodes as array (order may vary)

#### 8.6 Nested Collections
```
[[Int]], [[[String]]], [[String: Int]]
```

#### 8.7 Empty Collections
```
[Int](), [String: Int](), Set<Int>()
```

#### 8.8 Large Collections
```
Array with 10,000 elements
Dictionary with 10,000 entries
```

#### 8.9 Collection of Optionals
```
[Int?], [String: Int?]
```

**Verification Approach**:
- Round-trip testing
- Verify XPC structure (array count, dictionary keys)
- Performance baseline for large collections (optional)

---

### Suite 9: StandardLibraryTypeTests.swift

**Purpose**: Verify encoding/decoding of Foundation and standard library types.

**File Name**: `Tests/XPCCodingTests/Suites/StandardLibraryTypeTests.swift`

**Capabilities Being Verified**:
- URL encoding/decoding
- UUID encoding/decoding
- Date encoding (as Double/TimeInterval)
- Decimal encoding
- Range types (if Codable)
- CGPoint, CGSize, CGRect (if available)

**Test Cases**:

#### 9.1 URL Variations
```
- http URL
- https URL
- file URL
- URL with query parameters
- URL with special characters (percent encoded)
- Invalid URL handling
```

#### 9.2 UUID
```
- Random UUID
- Nil UUID (00000000-0000-0000-0000-000000000000)
- Specific known UUID
```

#### 9.3 Date
```
- Current date
- Epoch (Date(timeIntervalSince1970: 0))
- Distant past
- Distant future
- Date with fractional seconds
```

#### 9.4 Decimal
```
- Zero
- Positive/negative
- Very large
- Very small
- Maximum precision
```

**Verification Approach**:
- Round-trip testing
- Verify encoded representation matches expectation (e.g., URL as string)

**Implementation Notes**:
- Some types may not be directly supported; document limitations
- May need custom encoding strategies for some types

---

### Suite 10: ErrorConditionTests.swift

**Purpose**: Verify all error conditions are properly detected and reported.

**File Name**: `Tests/XPCCodingTests/Suites/ErrorConditionTests.swift`

**Capabilities Being Verified**:
- `EncodingError.invalidValue` thrown appropriately
- `DecodingError.typeMismatch` for wrong XPC type
- `DecodingError.keyNotFound` for missing keys
- `DecodingError.dataCorrupted` for invalid data
- Proper error context (codingPath, debugDescription)
- XPCDecoder constructor rejects non-dictionaries

**Test Cases**:

#### 10.1 Encoding Errors

##### 10.1.1 Custom Type Throws During Encoding
```
struct ThrowsOnEncode: Encodable {
  func encode(to encoder: Encoder) throws {
    throw CustomError()
  }
}
```

##### 10.1.2 Nested Encoding Failure
- Verify error context includes full path

#### 10.2 Decoding Errors

##### 10.2.1 Type Mismatch - Primitives
```
XPC string → decode as Int → typeMismatch
XPC int64 → decode as String → typeMismatch
XPC bool → decode as Double → typeMismatch
```

##### 10.2.2 Type Mismatch - Containers
```
XPC array → decode as keyed → typeMismatch
XPC dictionary → decode as unkeyed → typeMismatch
```

##### 10.2.3 Key Not Found
```
Decode struct with required field from XPC dict without that key
```
- Verify `DecodingError.keyNotFound`
- Verify error includes the missing key

##### 10.2.4 Data Corrupted
- Invalid XPC structure for expected type

##### 10.2.5 Array Index Out of Bounds
- Attempt to decode more elements than array contains
- Verify appropriate error

#### 10.3 XPCDecoder Initialization

##### 10.3.1 Reject Non-Dictionary
```
let array = xpc_array_create(nil, 0)
XPCDecoder(decoding: array) // Should throw
```
- Test with: array, string, int64, bool, data, null

##### 10.3.2 Accept Dictionary
```
let dict = xpc_dictionary_create(nil, nil, 0)
XPCDecoder(decoding: dict) // Should succeed
```

#### 10.4 Error Context Verification

##### 10.4.1 Shallow Path
- Verify `codingPath` has 1 element for top-level field error

##### 10.4.2 Deep Path (depth 3-5)
- Verify `codingPath` has correct depth and keys

##### 10.4.3 Array Index in Path
- Error in array element should include index in path

**Verification Approach**:
- Use `#expect(throws:)` to verify specific error types
- Extract error context and verify `codingPath`, `debugDescription`
- Test all documented error conditions

---

### Suite 11: CodingPathTests.swift

**Purpose**: Verify `codingPath` is correctly maintained throughout encoding and decoding.

**File Name**: `Tests/XPCCodingTests/Suites/CodingPathTests.swift`

**Capabilities Being Verified**:
- `codingPath` correct at top level (empty)
- `codingPath` correct in keyed container (includes key)
- `codingPath` correct in unkeyed container (includes index)
- `codingPath` correct in single-value container
- `codingPath` correct in nested containers
- `codingPath` preserved through `superEncoder`/`superDecoder`

**Test Cases**:

#### 11.1 Top-Level Path
- Encoder.codingPath is empty at start

#### 11.2 Keyed Container Path
```
struct S { var field: Tracker }
// Tracker records codingPath during encode/decode
```
- Verify path is [CodingKey("field")]

#### 11.3 Unkeyed Container Path
```
[Tracker, Tracker, Tracker]
```
- Verify paths are [CodingKey(0)], [CodingKey(1)], [CodingKey(2)]

#### 11.4 Nested Path
```
struct Outer { var inner: Inner }
struct Inner { var value: Tracker }
```
- Verify path is [CodingKey("inner"), CodingKey("value")]

#### 11.5 Deep Nesting (5 levels)
- Verify path grows correctly

#### 11.6 Super Encoder Path
```
class Parent: Codable { }
class Child: Parent { var field: Tracker }
```
- Verify path includes "super" key when using superEncoder

#### 11.7 Path After Container Exit
- Verify path returns to previous state after nested container exits
- (This tests the `withTransientCodingPathElement` mechanism)

**Verification Approach**:
- Create `CodingPathTracker` type that records path during encode/decode
- Compare recorded paths against expected
- Test both encoding and decoding paths

**Implementation Notes**:
- This suite tests internal invariants, may require `@testable import`

---

### Suite 12: EdgeCaseTests.swift

**Purpose**: Verify behavior at boundaries and with unusual inputs.

**File Name**: `Tests/XPCCodingTests/Suites/EdgeCaseTests.swift`

**Capabilities Being Verified**:
- Handling of extreme values
- Unicode edge cases
- Very deep/wide structures
- Empty structures at various levels
- Keys with special characters

**Test Cases**:

#### 12.1 Numeric Edge Cases

##### 12.1.1 Integer Boundaries
```
Int8.min, Int8.max, Int16.min, Int16.max, ...
Int.min, Int.max, UInt.max
```

##### 12.1.2 Floating Point Special Values
```
Double.nan (verify isNaN after decode)
Double.infinity, Double.signalingNaN
Float.ulpOfOne, Float.leastNonzeroMagnitude
```

##### 12.1.3 Zero Variations
```
0, -0 for Float/Double
0 for all integer types
```

#### 12.2 String Edge Cases

##### 12.2.1 Empty String
```
""
```

##### 12.2.2 Unicode Strings
```
"Hello 🌍"
"مرحبا" (Arabic)
"你好" (Chinese)
"🇺🇸🇬🇧🇯🇵" (Flag sequences)
"\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}" (Family emoji)
```

##### 12.2.3 Control Characters
```
"Hello\0World" (embedded null)
"Line1\nLine2" (newline)
"Tab\there" (tab)
```

##### 12.2.4 Very Long String
```
String(repeating: "x", count: 1_000_000)
```

#### 12.3 Data Edge Cases

##### 12.3.1 Empty Data
```
Data()
```

##### 12.3.2 All Byte Values
```
Data(0...255)
```

##### 12.3.3 Large Data
```
Data(repeating: 0, count: 10_000_000)
```

#### 12.4 Structure Edge Cases

##### 12.4.1 Deeply Nested (20 levels)
- Verify no stack overflow or corruption

##### 12.4.2 Wide Structure (1000 keys)
- Dictionary with 1000 top-level keys

##### 12.4.3 Many Empty Nested Containers
```
{ "a": {}, "b": [], "c": { "d": [], "e": {} } }
```

#### 12.5 Key Edge Cases

##### 12.5.1 Key with Special Characters
```
Keys: "hello world", "key.with.dots", "key/with/slashes", "key:colon", "日本語key"
```

##### 12.5.2 Empty Key
```
CodingKey with stringValue: ""
```

##### 12.5.3 Numeric String Key
```
CodingKey with stringValue: "123"
```

#### 12.6 Re-encoding Stability

##### 12.6.1 Encode → Decode → Re-encode
- Verify re-encoded value matches original encoding

**Verification Approach**:
- Round-trip testing with boundary values
- Explicit verification for special cases (NaN, etc.)
- Performance/timeout guards for large data tests

---

## Support Files

### TestTypes.swift

**Purpose**: Define shared test types used across multiple suites.

**Contents**:
- `PrimitiveWrapper<T>` - Wraps a single primitive for keyed container testing
- `CodingPathTracker` - Records codingPath during encode/decode
- `ThrowingEncoder`/`ThrowingDecoder` - Force errors at specific points
- Level0-Level6 class hierarchy for inheritance tests
- Various nested structure types

### TestHelpers.swift

**Purpose**: Define shared test utilities.

**Contents**:
```swift
/// Verifies a value round-trips correctly through XPC encoding
func verifyRoundTrip<T: Codable & Equatable>(_ value: T) throws

/// Verifies XPC object has expected type
func verifyXPCType(_ object: xpc_object_t, is type: xpc_type_t)

/// Creates XPC dictionary with specific structure for decoding tests
func createXPCDictionary(_ pairs: [(String, xpc_object_t)]) -> xpc_object_t

/// Creates XPC array for decoding tests
func createXPCArray(_ values: [xpc_object_t]) -> xpc_object_t

/// Compares floats accounting for NaN
func equivalentFloats<F: FloatingPoint>(_ a: F, _ b: F) -> Bool
```

### TestTags.swift

**Purpose**: Define tags for test filtering.

**Contents**:
```swift
extension Tag {
  @Tag static var encoding: Self
  @Tag static var decoding: Self
  @Tag static var roundTrip: Self
  // ... (as listed above)
}
```

---

## Migration Strategy

### Phase 1: Setup Infrastructure
1. Create directory structure
2. Create TestTags.swift
3. Create TestHelpers.swift with basic utilities
4. Create TestTypes.swift with initial types

### Phase 2: Migrate Existing Tests
1. Port each existing XCTest to Swift Testing equivalent
2. Add appropriate tags
3. Verify all migrated tests pass
4. Keep original file as reference until migration complete

### Phase 3: Implement New Suites (Priority Order)
1. **PrimitiveTypeTests** - Foundation for all other tests
2. **ErrorConditionTests** - Verify error handling works
3. **KeyedContainerTests** - Most common usage pattern
4. **UnkeyedContainerTests** - Second most common
5. **SingleValueContainerTests** - Important for enum patterns
6. **OptionalAndNilTests** - Critical for real-world usage
7. **InheritanceTests** - Important for class hierarchies
8. **NestedContainerTests** - Complex patterns
9. **CollectionTests** - Common patterns
10. **StandardLibraryTypeTests** - Practical usage
11. **CodingPathTests** - Internal verification
12. **EdgeCaseTests** - Boundary conditions

### Phase 4: Cleanup
1. Remove LegacyTests directory
2. Update documentation
3. Verify CI/CD runs all new tests

---

## Implementation Notes for Future Agents

### Swift Testing Best Practices

1. **Use `@Test` with tags**: Every test should have at least one tag
```swift
@Test(.tags(.primitives, .roundTrip))
func booleanRoundTrip() { ... }
```

2. **Use parameterized tests**: Prefer `@Test(arguments:)` over multiple similar tests
```swift
@Test(arguments: [Int8.min, Int8.max, 0, 1, -1])
func int8RoundTrip(value: Int8) { ... }
```

3. **Use `@Suite` for organization**:
```swift
@Suite("Primitive Types", .tags(.primitives))
struct PrimitiveTypeTests { ... }
```

4. **Use `#expect` not XCTAssert**:
```swift
#expect(decoded == original)
#expect(throws: DecodingError.self) { ... }
```

5. **Use `withKnownIssue` for expected failures**:
```swift
withKnownIssue("NaN doesn't equal itself") {
  #expect(Float.nan == Float.nan)
}
```

### XPC-Specific Considerations

1. **XPC types are reference types**: Use `xpc_retain`/`xpc_release` if storing
2. **Type mapping**:
   - Int8, Int16, Int32, UInt8, UInt16, UInt32, Float16, Float → XPC_TYPE_DATA
   - Int64, Int → XPC_TYPE_INT64
   - UInt64, UInt → XPC_TYPE_UINT64
   - Double → XPC_TYPE_DOUBLE
   - String → XPC_TYPE_STRING
   - Data → XPC_TYPE_DATA
   - Bool → XPC_TYPE_BOOL
3. **Null handling**: XPC has explicit null type (`XPC_TYPE_NULL`)

### Testing Infrastructure

1. **Import requirements**:
```swift
import Testing
import Foundation
import XPC
@testable import XPCCoding
```

2. **Concurrency**: Tests run concurrently by default; ensure no shared mutable state

3. **Error verification**:
```swift
#expect {
  try XPCDecoder.decode(T.self, message: badXPC)
} throws: { error in
  guard let decodingError = error as? DecodingError else { return false }
  // Verify specific error properties
  return true
}
```

---

## Appendix: XPC Type Reference

| Swift Type | XPC Type | Notes |
|------------|----------|-------|
| Bool | XPC_TYPE_BOOL | |
| Int | XPC_TYPE_INT64 | Via Int64 |
| Int8 | XPC_TYPE_DATA | Binary representation |
| Int16 | XPC_TYPE_DATA | Binary representation |
| Int32 | XPC_TYPE_DATA | Binary representation |
| Int64 | XPC_TYPE_INT64 | Native |
| Int128 | XPC_TYPE_DATA | Binary representation |
| UInt | XPC_TYPE_UINT64 | Via UInt64 |
| UInt8 | XPC_TYPE_DATA | Binary representation |
| UInt16 | XPC_TYPE_DATA | Binary representation |
| UInt32 | XPC_TYPE_DATA | Binary representation |
| UInt64 | XPC_TYPE_UINT64 | Native |
| UInt128 | XPC_TYPE_DATA | Binary representation |
| Float16 | XPC_TYPE_DATA | Binary representation |
| Float | XPC_TYPE_DATA | Binary representation |
| Double | XPC_TYPE_DOUBLE | Native |
| String | XPC_TYPE_STRING | |
| Data | XPC_TYPE_DATA | |
| nil | XPC_TYPE_NULL | |
| Dictionary | XPC_TYPE_DICTIONARY | |
| Array | XPC_TYPE_ARRAY | |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-21 | Claude | Initial plan document |
