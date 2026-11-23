# Registry TODO

- [ ] **Add CI port-install verification workflow**:
  - Add a GitHub Actions workflow on pull requests that runs `vcpkg install` for modified ports to verify they configure and install cleanly.

- [ ] **Distribute shared `.clang-format` / `.clang-tidy` templates via `cpp-bestpractices`**:
  - Install reference `.clang-format` and `.clang-tidy` templates into `share/cpp-bestpractices/configs/`.
  - Add conditional sync on configure (outside `CI`, via `cpp_bestpractices_sync_configs()` or a vcpkg feature) using a `# managed-by: cpp-bestpractices v<N>` version marker (rather than raw file mtime, since git checkout and vcpkg binary-cache unpack reset timestamps) so missing or older managed configs update automatically while customized project configs are preserved.

- [ ] **Add `cpp-bestpractices::lto` (IPO/LTO) target**:
  - Add an opt-in `INTERFACE` target (e.g., `cpp-bestpractices::lto`) that enables Link-Time / Interprocedural Optimization (`-flto` / `/GL`, or `INTERPROCEDURAL_OPTIMIZATION` via `CheckIPOSupported`) only for `Release` and `RelWithDebInfo` configurations.
