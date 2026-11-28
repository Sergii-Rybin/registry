---
name: pulse
description: >-
  Guide for using the pulse header-only C++23 compile-time type-routed signals
  library (pulse::Bus, pulse::Out, pulse::FirstOf, pulse::Drop, pulse::DynamicPort,
  and optional C++26 pulse/pulse_meta.hpp).
---

# Using `pulse`

`pulse` is a header-only C++23 library for compile-time type-routed signals with zero allocation, no RTTI, and no virtual dispatch.

## CMake Integration

```cmake
find_package(pulse CONFIG REQUIRED)
target_link_libraries(my_target PRIVATE pulse::pulse)
```

## Core Primitives (`#include <pulse/pulse.hpp>`)

- **Signals**: Plain value types — the type itself is the routing address.
- **Receivers**: Any object with `on(...)` overloads or any callable. Ordinary overload resolution selects one handler per receiver.
- **Return-type forwarding**:
  - `void`, `pulse::None`, `std::monostate` -> emits nothing
  - `T` -> emits `T`
  - `std::optional<T>` -> emits `T` if engaged
  - `std::variant<Ts...>` -> emits active alternative
  - `std::expected<T, E>` -> emits `T` or `E`
  - `std::tuple<Ts...>` -> emits every element
  - `std::generator<T>` -> emits `0..N` values
- **`pulse::Out<Ts...>`**: Typed output port for non-template handlers (`void on(const Overheat&, pulse::Out<Log, Shutdown> emit)`).
- **`pulse::Bus`**: Compile-time multicast (`pulse::Bus app{a, b, c}; app.send(x);`). Nested buses bubble unhandled signals upward; dead signals at the top level fail at compile time unless explicitly discarded with `pulse::Drop<Ts...>`.
- **`pulse::FirstOf`**: Priority/fallback routing to the first matching receiver.
- **`pulse::DynamicPort<Ts...>`**: Runtime subscriber edge (`port.connect<S>(fn)`).
- **`pulse::handles<R, S>`**: Concept querying whether receiver `R` handles signal `S`.
