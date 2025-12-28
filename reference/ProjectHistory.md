# Project History

This project is a fork of [https://github.com/daniel-grumberg/CodableXPC](https://github.com/daniel-grumberg/CodableXPC), which appears to no longer be maintained.

The initial plan was to fork the project, ensure it handled Swift 6, expand the unit test suite to verify its correctness, and then do some light stylistic adjustments to bring it into alignment with other projects in the "hdxl" ecosystem.
After adjusting the code style and expanding the test suite, however, I discovered one API-design issue and two significant limitations I wanted to address:

- API design:
  - original: directly exposed `Encoder` and `Decoder`-conforming types
  - adjusted: expose `TopLevelEncoder`/`TopLevelDecoder`-conforming types (with actual `Encoder`/`Decoder` types kept project-internal)
- limitation: embedded null-byte handling
  - original: naively use underlying truncate string keys and values containing embedded null bytes
  - adjusted: user-configurable behavior vis-a-vis handling of string keys and values with embedded null bytes
- limitation: lack of support for "simple" root values
  - original: only supported complex single values as root values (e.g. anything that'd get encoded to a dictionary-like `xpc_object_t` value, like structs, etc.)
  - adjusted: added support for any arbitrary `Codable` types as a "root value"

After making these adjustments and debugging the code, I then proceeded to refactor the agent-generated test suites to be more-targeted and more-maintainable.
This remains a work-in-progress, however, and there's still a fair amount of work to be done.

In any case, this project doesn't *quite* have a single consistent style at this time:

- the implementation is mostly "hdxl style swift", but still has traces of the original style here and there
- the test suite is a mix of four styles:
  - the original test suite, but converted to Swift Testing and partially "hdxlified"
  - some targeted, hand-written test suites
  - some refactored agent-generated suites
  - some largely-unmodified agent-generated suites
- the test package also contains a large amount of miscellaneous code in mixed styles:
  - two inventories of "test types" (one from the original, one mostly agent-generated with light hand-editing)
  - multiple groups of "test helpers" (some of which are unmodified from the original, some of which are "hdxlified")
