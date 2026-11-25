---
name: typelist
description: >-
  Guide for using the C++23 `typelist` module (`import typelist;`) and the optional
  C++26 reflection `typelist.reflect` module (`import typelist.reflect;`) for
  canonical, sorted, deduplicated compile-time type sets.
---

# Using `typelist`

`typelist` provides a zero-dependency C++23 module (`import typelist;`) implementing canonical, sorted, deduplicated compile-time type lists (`typelist::TypeList`, `typelist::MakeTypeList`), plus an independent C++26 reflection module (`import typelist.reflect;`, `typelist::reflect::TypeList`) when the `reflection` feature is enabled.

## CMake Integration

```cmake
find_package(typelist CONFIG REQUIRED)
target_link_libraries(my-target PRIVATE typelist::typelist)

# Optional (requires vcpkg feature "reflection" and C++26 `-freflection`, e.g. GCC 16+):
# target_link_libraries(my-reflect-target PRIVATE typelist::reflect)
```

## Quick Reference (`import typelist;`)

```cpp
import typelist;
import std;

using List = typelist::MakeTypeList<int, double, char, int>;
using Extended = List::Add<float, char>;

static_assert(Extended::size == 4);
static_assert(Extended::contains<double>);
static_assert(std::is_same_v<typelist::MakeTypeList<char, int, double>, typelist::MakeTypeList<double, char, int>>);

constexpr auto idx = Extended::indexOf<double>();
constexpr auto names = Extended::typeNames();
Extended::forEach([]<class T>(typelist::Tag<T>) {
    // Invoked in canonical sorted order
});
```

## C++26 Reflection Variant (`import typelist.reflect;`)

Requires GCC 16+ with `-std=c++26 -freflection` and pure `import std;` (avoid mixing `<meta>` or conflicting standard headers with `import typelist.reflect;` in the same translation unit). Uses `std::meta::display_string_of` and `std::meta::substitute` in `typelist::reflect::MakeTypeList` with the same API surface (`Tag`, `typeKey`, `typeLess`, `TypeList`, `MakeTypeList`).
