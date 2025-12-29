set quiet

# building
mod build './commands/build.just'

# testing
mod test './commands/test.just'

# checking and generating documentation
mod docs './commands/docs.just'

# linting
mod lint './commands/lint.just'

# formatting
mod format './commands/format.just'

# checking for todos
mod todos './commands/todos.just'

[private]
default:
  @just --list --unsorted


# builds-and-tests
[group('convenience')]
check:
  @just build debug
  @just test debug
