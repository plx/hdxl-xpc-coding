set quiet

[private]
default:
    @just --list build --unsorted

# build the package in debug
[group('debug')]
debug:
    swift build

# build the package in release
[group('release')]
release:
    swift build -c release

# build both real configurations
[group('aggregates')]
all: debug release
