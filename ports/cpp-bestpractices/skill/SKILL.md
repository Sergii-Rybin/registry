---
name: cpp-bestpractices
description: >-
  Guide for configuring and using cpp-bestpractices CMake INTERFACE targets
  (lite, cpp-bestpractices, paranoid, werror, hardening, asan, tsan) and CMake
  helpers (ccache, clang-format targets, legacy docs sync) in C++ projects.
---

# Using `cpp-bestpractices`

`cpp-bestpractices` provides composable CMake `INTERFACE` targets for compiler warnings, standard library hardening, and sanitizers, plus CMake helpers for `ccache` and `clang-format`.

## Available Targets

- `cpp-bestpractices::lite` — baseline warnings (`-Wall -Wextra -Wpedantic` / `/W4 /permissive-`) and cross-platform hygiene (`/utf-8`, `/Zc:__cplusplus`, `/Zc:preprocessor`, colored diagnostics).
- `cpp-bestpractices::cpp-bestpractices` — recommended strict C++ Best Practices warnings (includes `lite`, plus `-Wshadow`, `-Wconversion`, `-Wold-style-cast`, GCC-only `-Wduplicated-*`/`-Wlogical-op`/`-Wuseless-cast`, and extended MSVC warnings).
- `cpp-bestpractices::paranoid` — extra-strict checks for critical core modules (includes `cpp-bestpractices`, plus `-Wcast-qual`, `-Wundef`, `-Wswitch-enum`, `-Wfloat-equal`, `-Wzero-as-null-pointer-constant`, etc.).
- `cpp-bestpractices::werror` — treats warnings as errors (`-Werror` / `/WX`). Prefer enabling via a CI CMake option rather than unconditionally.
- `cpp-bestpractices::hardening` — enables low-overhead STL bounds/precondition assertions (`_GLIBCXX_ASSERTIONS` / `_LIBCPP_HARDENING_MODE_FAST`).
- `cpp-bestpractices::asan` — Address & Undefined Behavior Sanitizers (`-fsanitize=address,undefined` / `/fsanitize=address`).
- `cpp-bestpractices::tsan` — Thread Sanitizer (`-fsanitize=thread`).

## Recommended Usage

- For **applications / non-exported targets**, link `PRIVATE` so flags do not propagate.
- For **installable / exported libraries** (`install(EXPORT ...)`), gate `find_package(cpp-bestpractices)` by `if(PROJECT_IS_TOP_LEVEL)` and link via **`PRIVATE $<BUILD_LOCAL_INTERFACE:...>`** so `*-targets.cmake` never references `cpp-bestpractices::*` and downstream consumers have zero transitive dev dependencies.

```cmake
if(PROJECT_IS_TOP_LEVEL)
    find_package(cpp-bestpractices CONFIG REQUIRED)
    cpp_bestpractices_enable_ccache()

    option(WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)
    option(ENABLE_SANITIZERS "Enable Address & UB Sanitizers" OFF)

    # Exported library: wrap in $<BUILD_LOCAL_INTERFACE:...>
    target_link_libraries(my_core_lib PRIVATE
        $<BUILD_LOCAL_INTERFACE:
            cpp-bestpractices::paranoid
            cpp-bestpractices::hardening
            $<$<BOOL:${WARNINGS_AS_ERRORS}>:cpp-bestpractices::werror>
            $<$<BOOL:${ENABLE_SANITIZERS}>:cpp-bestpractices::asan>
        >
    )

    # Non-exported test target: plain PRIVATE is sufficient
    target_link_libraries(my_tests PRIVATE
        cpp-bestpractices::lite
    )

    # Register `format` and `format-check` targets (collects SOURCES, HEADER_SET, CXX_MODULE_SET)
    cpp_bestpractices_add_format_targets(my_core_lib my_tests)
endif()
```

## CMake Helpers

- `cpp_bestpractices_enable_ccache()` — enables `ccache` as `CMAKE_{C,CXX}_COMPILER_LAUNCHER` on `Ninja` and `Makefiles` generators (skipped on others). On MSVC, automatically switches Debug/RelWithDebInfo debug info to `Embedded` (`/Z7`) so `ccache` works.
- `cpp_bestpractices_add_format_targets(<targets...>)` — registers `format` (`clang-format -i`) and `format-check` (`clang-format --dry-run --Werror`) collecting `SOURCES`, `HEADER_SET`, and `CXX_MODULE_SET` from the given targets.

## vcpkg `skills` Feature

Enable `"features": ["skills"]` in `vcpkg.json` to install this skill into `share/agent-skills/cpp-bestpractices`. When `find_package(cpp-bestpractices)` runs locally (skipped when `ENV{CI}` is set), `vcpkg-cmake-wrapper.cmake` automatically writes `.agents/skills.json` pointing to `share/agent-skills` so all vcpkg-delivered skills are discovered.

## Legacy: Documentation Sync

> [!NOTE]
> For new projects, prefer the dedicated **`docs-render`** host port (Inja templates, live snippets, and `subprocess`-backed executable output capture) over `cpp_bestpractices_add_docs_targets`.

`cpp_bestpractices_add_docs_targets(FILES README.md TARGETS my_example [TIMEOUT 15])` remains available for existing projects (`docs-sync` and `docs-check` targets, respecting `CMAKE_CROSSCOMPILING_EMULATOR`):
- In Markdown: `<!-- snippet: path.cpp#region --> ... <!-- end-snippet -->` and `<!-- output: target [args...] --> ... <!-- end-output -->`
- In C++ sources: `// [snippet:region]` … `// [end:region]`, single-line `// [hide]`, or block `// [hide]` … `// [end-hide]`
