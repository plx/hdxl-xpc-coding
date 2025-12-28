# hdxl-xpc-codable

A Swift encoder/decoder pair producing xpc objects as output.

This is a heavily refactored fork of [CodableXPC](https://github.com/daniel-grumberg/CodableXPC).

Aside from renaming, reorganization, and purely-stylistic changes, this package:

- allows arbitrary values to be the "root value" of an archive
- adopts the `TopLevelEncoder`-facade pattern used by `JSONEncoder`/`JSONDecoder`
- reduces the public API surface to the necessary portions
- correctly handles strings with embedded null bytes (and provides user-configurable strategies for doing so)
- provides a "codec" mechanism for obtaining compatible encoder/decoder pairs
- provides auxiliary API allowing more-efficient encoding for clients working with lower-level data (e.g. APIs to encode raw byte buffers *without* wrapping in a transient `Data`)  
- has an extensive unit-test suite validating 

