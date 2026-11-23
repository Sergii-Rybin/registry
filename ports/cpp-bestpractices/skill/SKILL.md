---
name: cpp-bestpractices
description: >-
  Guide for configuring and using cpp-bestpractices CMake INTERFACE targets
  (lite, cpp-bestpractices, paranoid, werror, hardening, asan, tsan) in C++ projects.
---

# Using `cpp-bestpractices`

`cpp-bestpractices` provides composable CMake `INTERFACE` targets for compiler warnings, standard library hardening, and sanitizers.

## Available Targets

- `cpp-bestpractices::lite` — baseline warnings (`-Wall -Wextra -Wpedantic` / `/W4 /permissive-`) and cross-platform hygiene (`/utf-8`, `/Zc:__cplusplus`, `/Zc:preprocessor`, colored diagnostics).
- `cpp-bestpractices::cpp-bestpractices` — recommended strict C++ Best Practices warnings (includes `lite`, plus `-Wshadow`, `-Wconversion`, `-Wold-style-cast`, GCC-only `-Wduplicated-*`/`-Wlogical-op`/`-Wuseless-cast`, and extended MSVC warnings).
- `cpp-bestpractices::paranoid` — extra-strict checks for critical core modules (includes `cpp-bestpractices`, plus `-Wcast-qual`, `-Wundef`, `-Wswitch-enum`, `-Wfloat-equal`, `-Wzero-as-null-pointer-constant`, etc.).
- `cpp-bestpractices::werror` — treats warnings as errors (`-Werror` / `/WX`). Prefer enabling via a CI CMake option rather than unconditionally.
- `cpp-bestpractices::hardening` — enables low-overhead STL bounds/precondition assertions (`_GLIBCXX_ASSERTIONS` / `_LIBCPP_HARDENING_MODE_FAST`).
- `cpp-bestpractices::asan` — Address & Undefined Behavior Sanitizers (`-fsanitize=address,undefined` / `/fsanitize=address`).
- `cpp-bestpractices::tsan` — Thread Sanitizer (`-fsanitize=thread`).

## Recommended Usage

Always link targets `PRIVATE` to avoid leaking warning flags into external consumers of your libraries:

```cmake
find_package(cpp-bestpractices CONFIG REQUIRED)
cpp_bestpractices_enable_ccache()

option(WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)
option(ENABLE_SANITIZERS "Enable Address & UB Sanitizers" OFF)

target_link_libraries(my_core_lib PRIVATE
    cpp-bestpractices::paranoid
    cpp-bestpractices::hardening
    $<$<BOOL:${WARNINGS_AS_ERRORS}>:cpp-bestpractices::werror>
    $<$<BOOL:${ENABLE_SANITIZERS}>:cpp-bestpractices::asan>
)

target_link_libraries(my_tests PRIVATE
    cpp-bestpractices::lite
)

# Register `format` and `format-check` targets (collects SOURCES, HEADER_SET, CXX_MODULE_SET)
cpp_bestpractices_add_format_targets(my_core_lib my_tests)
```
