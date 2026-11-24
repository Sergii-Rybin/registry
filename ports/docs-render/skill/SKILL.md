---
name: docs-render
description: >-
  Guide for configuring and using the docs-render vcpkg host tool and CMake
  helper (docs_render_add_targets) to render documentation in-place or from
  Inja templates with live code snippets, optional JSON metadata, and
  executable outputs.
---

# Using `docs-render`

`docs-render` is a host-only C++23 CLI tool powered by Inja and `nlohmann-json` that keeps documentation in sync with live source code snippets, optional JSON metadata, and verified executable outputs.

## Adding `docs-render` to `vcpkg.json`

Declare `docs-render` with `"host": true` so vcpkg builds it for the host machine even when cross-compiling:

```json
{
  "dependencies": [
    {
      "name": "docs-render",
      "host": true,
      "features": ["skills"]
    }
  ]
}
```

## Registering CMake Targets

Call `find_package(docs-render CONFIG REQUIRED)` and `docs_render_add_targets(...)`.
`DATA` is optional — only pass `DATA key=file.json` if your document references JSON metadata (such as `{{ vcpkg.version }}`).

### In-Place Mode (No `.in` File Needed)

Update `<!-- inja: ... -->` / `<!-- inja(lang): ... -->` blocks directly inside one or more Markdown files:

```cmake
find_package(docs-render CONFIG REQUIRED)

docs_render_add_targets(
    IN_PLACE README.md
    TARGETS my_example
)
```

### Template Mode

Render an entire output file from a template file:

```cmake
find_package(docs-render CONFIG REQUIRED)

docs_render_add_targets(
    TEMPLATE README.md.in
    OUTPUT README.md
    DATA vcpkg=vcpkg.json
    TARGETS my_example
    TIMEOUT 15
)
```

Both modes register two CMake custom targets that automatically depend on `TARGETS`:

- `docs-render`: updates the documentation (skips rewriting when content is unchanged).
- `docs-render-check`: verifies the documentation is up to date and exits with code `1` if out of date (ideal for CI).

## In-Place Markers

- Raw output between markers:
  ```markdown
  <!-- inja: {{ vcpkg.version }} -->
  1.0.0
  <!-- end-inja -->
  ```
- Fenced code block (` ```<lang> ... ``` `) between markers:
  ```markdown
  <!-- inja(cpp): {{ snippet("src/main.cpp", "usage") }} -->
  ```cpp
  ...
  ```
  <!-- end-inja -->

  <!-- inja(text): {{ output("my_example", "World") }} -->
  ```text
  Hello, World!
  ```
  <!-- end-inja -->
  ```

## Inja Helpers

- **JSON data (optional)**: `--data vcpkg=vcpkg.json` exposes the parsed JSON under `vcpkg`, e.g. `{{ vcpkg.name }}` or `{{ vcpkg.version }}`.
- **Code snippets**:
  - `{{ snippet("src/main.cpp") }}` — includes the whole file (CRLF normalized to LF, dedented).
  - `{{ snippet("src/main.cpp", "demo") }}` — extracts lines strictly between `// [snippet:demo]` and `// [end:demo]`.
  - Hide lines inside snippets using single-line `// [hide]` or block `// [hide]` ... `// [end-hide]`.
- **Executable outputs**:
  - `{{ output("my_example") }}` or `{{ output("my_example", "World") }}` — runs the registered target (respecting `CMAKE_CROSSCOMPILING_EMULATOR` and `TIMEOUT`), fails if exit code != 0, and returns trimmed stdout.
