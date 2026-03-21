# Rules

- Prefer minimalist solutions. Target highly skilled engineers — readability is not a priority.
- Prefer removing or reducing code over adding more.
- No comments unless the logic is non-obvious. No doc comments.

## Platform and language

- Target: iOS 18
- Language mode: Swift 6
- Use modern concurrency with async, tasks and actors, never the old DispatchQueue interfaces.

## Code Style

- `else` always on its own line.
- No trailing spaces on empty lines.
- Keep function calls, as well as `if` and `guard` conditions on a single line. Don't break them across lines.
- Prefer single-line statements in general.
- `switch` case labels are indented.
- Omit `return` in single-expression functions.
