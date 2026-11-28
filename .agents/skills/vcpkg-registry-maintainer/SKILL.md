---
name: vcpkg-registry-maintainer
description: >-
  Maintains the personal vcpkg git registry at /run/media/sergii/Vault/omnis/registry
  (https://github.com/sergii-rybin/registry.git). Use when creating a new vcpkg port,
  updating an existing port version/REF/SHA512, modifying portfiles or features,
  syncing upstream releases, or updating vcpkg-configuration.json baselines in
  consumer repositories.
---

# vcpkg Registry Maintainer

Runbook for creating, updating, and verifying ports in the personal vcpkg git registry.

- **Local repository**: `/run/media/sergii/Vault/omnis/registry`
- **Remote**: `git@github.com:sergii-rybin/registry.git` (`https://github.com/sergii-rybin/registry.git`, branch `master`)
- **Tooling**: Always run `vcpkg` and `cmake` inside Docker (`ghcr.io/sergii-rybin/cpp-dev:latest` or the consumer repo's `docker compose run --rm dev`), never directly on the host.

## Reuse Registry Primitives

Before writing custom build helpers, scripts, or utilities in a new port or library, check `ports/` in `/run/media/sergii/Vault/omnis/registry` and reuse existing registry primitives:

- **Build hygiene, warnings, hardening, sanitizers, ccache & formatting** → `cpp-bestpractices` (`cpp-bestpractices::cpp-bestpractices`, `hardening`, `werror`, `asan`/`tsan`, `cpp_bestpractices_enable_ccache()`, `cpp_bestpractices_add_format_targets(...)`). In library repos, gate it by `PROJECT_IS_TOP_LEVEL` and link via `PRIVATE $<BUILD_LOCAL_INTERFACE:...>` (declared under a `"dev"` feature in `vcpkg.json`) so downstream consumers stay dependency-free.
- **Verified documentation & live snippets** → `docs-render` (Inja-based host tool + `docs_render_add_targets(...)`, declared with `"host": true` in `vcpkg.json`) instead of custom doc scripts or manually copied snippets.
- **Subprocess execution** → `subprocess` (`subprocess::subprocess`) instead of `popen` / `system` / ad-hoc OS process wrappers (e.g. `docs-render` uses `subprocess`).
- **`std::variant` visitors** → `overloaded` (`overloaded::overloaded`) instead of duplicating boilerplate `overloaded` structs.

## Port Archetypes

Choose the matching template from existing ports in `ports/`:

1. **External compiled library** (reference: `ports/subprocess/`):
   - Fetch via `vcpkg_from_git` or `vcpkg_from_github`.
   - Disable consumer-only options in `vcpkg_cmake_configure` (`-D<PROJ>_BUILD_TESTS=OFF`, `-D<PROJ>_BUILD_EXAMPLES=OFF`, `-D<PROJ>_BUILD_DOCS=OFF`, `-D<PROJ>_USE_BESTPRACTICES=OFF`).
   - Run `vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/<port>)` and `file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")`.
   - Ensure upstream `vcpkg.json` keeps `"dependencies": []` for zero-dependency libraries (dev/test deps go in `"features"`).
   - For C++23 module ports (`import std;`), verify compatibility with vcpkg's bundled CMake (4.4.x) as well as CMake 4.5+; patch experimental UUID via `vcpkg_replace_string(... IGNORE_UNCHANGED)` if required.

2. **External header-only library** (reference: `ports/overloaded/`):
   - Set `set(VCPKG_BUILD_TYPE release)` at the top of `portfile.cmake`.
   - Fetch via `vcpkg_from_github` with pinned `REF` and `SHA512`.
   - Install `include/` and run `vcpkg_cmake_configure` + `vcpkg_cmake_install` + `vcpkg_cmake_config_fixup`.

3. **In-registry CMake INTERFACE / helper port** (reference: `ports/cpp-bestpractices/`):
   - Set `set(VCPKG_BUILD_TYPE release)` and `set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)`.
   - Set `set(SOURCE_PATH "${CMAKE_CURRENT_LIST_DIR}")`.

4. **In-registry host CLI tool** (reference: `ports/docs-render/`):
   - Set `set(VCPKG_BUILD_TYPE release)` and `set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)`.
   - Call `vcpkg_copy_tools(TOOL_NAMES <binary> AUTO_CLEAN)`.
   - Consumers declare it with `"host": true` in `vcpkg.json` and locate it with:
     ```cmake
     find_package(<port> CONFIG REQUIRED
         HINTS "${VCPKG_INSTALLED_DIR}/${VCPKG_HOST_TRIPLET}/share/<port>"
         NO_CMAKE_FIND_ROOT_PATH
     )
     ```
     (`NO_CMAKE_FIND_ROOT_PATH` is mandatory when cross-compiling with `CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY`, e.g. `mingw-wine`.)

## Standard Files for Every Port

Every `ports/<name>/` directory must include:
- `vcpkg.json` (`$schema`, `name`, `version`, `description`, `"license": null` for the default commercial license, `dependencies` including host `vcpkg-cmake` / `vcpkg-cmake-config`, and `"features": { "skills": ... }` when shipping an AI skill).
- `portfile.cmake` (installs `usage`, copyright via `vcpkg_install_copyright(FILE_LIST "${CMAKE_CURRENT_LIST_DIR}/LICENSE")`, and `skill/` into `${CURRENT_PACKAGES_DIR}/share/agent-skills/${PORT}` when `"skills" IN_LIST FEATURES`).
- `usage` (concise consumer snippet including `find_package` and `target_link_libraries`).
- `LICENSE` — **Commercial License by default** (unless the user explicitly asks for an open-source license):
  ```text
  Commercial License

  Copyright (c) Sergii Rybin. All rights reserved.

  Ask Sergii Rybin for rights and licensing terms before use, modification, or distribution.
  ```
- `skill/SKILL.md` (if the `"skills"` feature is provided).

## Authentication & PAT Reminder

- Whenever a new or updated port references a **private** upstream repository, a **private** vcpkg registry, or a **private** GHCR container image, **explicitly remind the user to configure a GitHub PAT** (Personal Access Token with `repo` / `read:packages` scopes as needed) in GitHub Actions secrets / local git credentials, since the default `GITHUB_TOKEN` only has access to the current repository.

## Workflow: Creating or Modifying a Port

1. **Edit or scaffold `ports/<name>/`** following the archetype above.
   - If bumping the upstream version: update `"version"` (or `"version-semver"`) in `vcpkg.json` and **delete** `"port-version"`.
   - If modifying only port packaging (`portfile.cmake`, `usage`, `skill/`, etc.) without changing upstream version: **increment** `"port-version"` (add `"port-version": 1` if absent).
   - If updating a `vcpkg_from_github` port, compute `SHA512`:
     ```bash
     curl -fsSL "https://github.com/<owner>/<repo>/archive/<ref>.tar.gz" | sha512sum
     ```
   - Update `README.md` in the registry root if adding a new port or changing its description.

2. **Commit `ports/` FIRST** (required so git creates the `git-tree` object hash):
   ```bash
   cd /run/media/sergii/Vault/omnis/registry
   git add ports/<name> README.md
   git commit -m "feat(ports): <summary>"
   ```

3. **Register version metadata via `vcpkg x-add-version` inside Docker**:
   ```bash
   docker run --rm -v /run/media/sergii/Vault/omnis/registry:/workspace -w /workspace \
     ghcr.io/sergii-rybin/cpp-dev:latest \
     vcpkg \
       --x-builtin-ports-root=/workspace/ports \
       --x-builtin-registry-versions-dir=/workspace/versions \
       x-add-version <name> --verbose
   ```
   *(Pass `--overwrite-version` only when intentionally replacing an unpublished version.)*

4. **Amend `versions/` into the same commit and PUSH before touching consumers**:
   ```bash
   git add versions/
   git commit --amend --no-edit
   git push origin master
   ```
   > **CRITICAL**: Never update `"baseline"` in a consumer repository's `vcpkg-configuration.json` to an unpushed local registry commit — remote CI will fail with `upload-pack: not our ref`.

## Workflow: Syncing Upstream GitHub Releases

For `vcpkg_from_github` ports with active `REF` and `SHA512`:
- Run `./scripts/sync-ports.sh` inside Docker from `/run/media/sergii/Vault/omnis/registry`, review the resulting commit, and `git push origin master`.
- Ports using `vcpkg_from_git` (e.g. `subprocess`) are skipped by `sync-ports.sh` and must be updated manually using the workflow above.

## Workflow: Updating Consumer Repositories & Verification

1. Get the pushed registry `HEAD` SHA:
   ```bash
   git -C /run/media/sergii/Vault/omnis/registry rev-parse HEAD
   ```
2. Update `"baseline"` (and `"packages"` list if a new port was added) in the consumer's `vcpkg-configuration.json`.
3. Verify in Docker on both native and cross-compilation presets:
   ```bash
   docker compose run --rm dev cmake --preset default
   docker compose run --rm dev cmake --preset mingw-wine
   ```
4. If the port provides a `"skills"` feature or CMake targets, verify that installed files appear in `build/docker/<preset>/vcpkg_installed/<triplet>/share/`.
