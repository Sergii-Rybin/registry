# Custom vcpkg Registry

Personal [vcpkg](https://github.com/microsoft/vcpkg) git registry containing reusable C++ ports.

## Available Ports

- **`cpp-bestpractices`** — Composable CMake `INTERFACE` targets for compiler warnings (`lite`, `cpp-bestpractices`, `paranoid`, `werror`), STL `hardening`, and sanitizers (`asan`, `tsan`).
- **`docs-render`** — Inja-powered host CLI tool and CMake helper for rendering documentation with live code snippets, JSON metadata, and verified executable outputs.
- **`subprocess`** — Modern C++23 cross-platform subprocess library for Linux and Windows (header + C++23 module).
- **`overloaded`** — Header-only implementation of the `overloaded` visitor pattern for `std::variant`.

## Usage

Add this registry to your project's `vcpkg-configuration.json`:

```json
{
  "$schema": "https://raw.githubusercontent.com/microsoft/vcpkg-tool/main/docs/vcpkg-configuration.schema.json",
  "default-registry": {
    "kind": "git",
    "repository": "https://github.com/microsoft/vcpkg",
    "baseline": "<vcpkg-commit-sha>"
  },
  "registries": [
    {
      "kind": "git",
      "repository": "https://github.com/sergii-rybin/registry.git",
      "baseline": "<registry-commit-sha>",
      "packages": [
        "cpp-bestpractices",
        "docs-render",
        "overloaded"
      ]
    }
  ]
}
```

Then run `vcpkg x-update-baseline` in your consumer repository to pin the latest `baseline` commits.

## Syncing Upstream Releases

Run `./scripts/sync-ports.sh` from the repository root (or trigger the **Sync Registry Ports** GitHub Actions workflow) to check upstream repositories for newer release tags and update `ports/` and `versions/`.
