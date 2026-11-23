# Registry TODO

- [ ] **Fix `overloaded` CMake config vs `usage` mismatch**:
  - `ports/overloaded/usage` currently documents `find_package(overloaded CONFIG REQUIRED)` and `overloaded::overloaded`, while `ports/overloaded/portfile.cmake` only copies `include/` without installing a CMake config file.
  - Either install a proper CMake `INTERFACE` target (`overloaded-config.cmake` via `vcpkg_cmake_configure` / `vcpkg_cmake_install` / `vcpkg_cmake_config_fixup`), or update `ports/overloaded/usage` to document direct `#include` usage.

- [ ] **Pin `overloaded` to a release tag instead of `HEAD`**:
  - Remove `set(VCPKG_USE_HEAD_VERSION ON)` from `ports/overloaded/portfile.cmake`.
  - Uncomment and populate `REF` (e.g. `v1.0.0`) and `SHA512` so the port is reproducible, binary-cache friendly, and compatible with `scripts/sync-ports.sh` (keep `HEAD_REF master` for optional `--head` installs).

- [ ] **Add SPDX licenses, `$schema`, and copyright installation**:
  - Add `"$schema": "https://raw.githubusercontent.com/microsoft/vcpkg-tool/main/docs/vcpkg.schema.json"` and `"license": "<SPDX>"` to `ports/cpp-bestpractices/vcpkg.json` and `ports/overloaded/vcpkg.json`.
  - Add `vcpkg_install_copyright(...)` to each `portfile.cmake` to eliminate vcpkg's missing SPDX/copyright warning.

- [ ] **Add CI port-install verification workflow**:
  - Add a GitHub Actions workflow on pull requests that runs `vcpkg install` for modified ports to verify they configure and install cleanly.
