---
name: overloaded
description: >-
  How to use the overloaded header-only utility for std::visit with std::variant in C++.
---

# Using `overloaded`

`overloaded` provides the classic overloaded lambda visitor helper for `std::variant` (`#include <overloaded.h>`).

## CMake Integration

```cmake
find_package(overloaded CONFIG REQUIRED)
target_link_libraries(my-target PRIVATE overloaded::overloaded)
```

## C++ Example

```cpp
#include <overloaded.h>
#include <variant>

std::variant<int, double> value = 42;
std::visit(overloaded{
    [](int i) { /* handle int */ },
    [](double d) { /* handle double */ },
}, value);
```
