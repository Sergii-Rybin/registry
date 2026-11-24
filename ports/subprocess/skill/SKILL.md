---
name: subprocess
description: >-
  Guide for using the C++23 subprocess library (`subprocess::run`, `subprocess::spawn`,
  typed option tags, timeouts, and process-tree cleanup) on Linux and Windows.
---

# Using `subprocess`

`subprocess` is a zero-dependency C++23 library for launching and managing child processes on Linux and Windows.

## CMake Integration

```cmake
find_package(subprocess CONFIG REQUIRED)
target_link_libraries(my-target PRIVATE subprocess::subprocess)
```

## Quick Reference

```cpp
#include <subprocess/subprocess.hpp> // or: import subprocess;

using namespace std::chrono_literals;

auto result = subprocess::run(
    subprocess::AppName{"git"},
    subprocess::Params{"status", "--short"},
    subprocess::TimeOut{10s}
);

if (result.timedOut) { /* process tree killed on timeout */ }
if (result.status == subprocess::TerminationStatus::Exited && result.exitCode == 0) {
    // result.stdOut / result.stdErr
}
```
