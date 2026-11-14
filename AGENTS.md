# AGENTS.md

## Repository overview

This repository contains `setup.bash`, an interactive installer for a
personalized development environment on supported Ubuntu and OpenSUSE systems.
The installer selects toolsets and installs distribution packages or pinned
upstream releases with checked digests.

## Important files

- `setup.bash` - Small executable entrypoint. Keep it Bash-compatible and
  preserve its idempotent behavior.
- `lib/` - Sourced installer libraries grouped by responsibility.
- `tests/setup.bats` - Focused tests for pure selection and validation logic.
- `README.md` - User-facing usage, platform, toolset, and installation
  documentation. Update it when command-line behavior or supported tools
  change.
- `.pre-commit-config.yaml` - Repository checks for shell formatting,
  ShellCheck, Markdown linting, and final newlines.

## Current organization

The installer is split into sourced libraries grouped into these areas:

- CLI parsing, toolset selection, platform detection, and global runtime state
- Ubuntu and OpenSUSE package installation
- Pinned artifact digests, downloads, checksum verification, and installation
- Toolset orchestration and Docker-group configuration
- Bash prompt management

The structure is:

```text
setup.bash
lib/
  runtime.sh       # logging, errors, dry-run execution, cleanup
  manifest.sh      # pinned versions, revisions, and repository fingerprints
  cli.sh           # arguments and toolset selection
  platform.sh      # OS, architecture, and sudo detection
  packages-ubuntu.sh
  packages-opensuse.sh
  artifacts.sh     # pinned digests, downloads, verification, installation
  toolsets.sh       # toolset orchestration
  prompt.sh         # .bashrc management
tests/
  setup.bats
```

Keep `setup.bash` as the small executable entrypoint that sources the libraries
and calls `main`.

## Development workflow

1. Make the smallest change that addresses the requested behavior.
2. Use `./setup.bash --help` to verify command-line help changes.
3. Use `./setup.bash --dry-run` to inspect installer behavior without making
   system changes. Toolset selection is still interactive.
4. Validate all shell scripts with the shell formatter and ShellCheck, and
   validate all Markdown files with `markdownlint-cli2`.
5. Run the repository checks before submitting changes:

   ```bash
   pre-commit run --all-files
   ```

   For targeted validation, run:

   ```bash
   shfmt --diff --indent 2 path/to/script.bash
   shellcheck path/to/script.bash
   markdownlint-cli2 path/to/file.md
   ```

## Shell scripting conventions

- Use Bash, including `set -Eeuo pipefail`, and do not silently ignore
  failures.
- Quote expansions unless word splitting or pathname expansion is explicitly
  intended.
- Prefer existing helpers such as `run`, `die`, `log`, `toolset_enabled`,
  `expected_asset_digest`, and `install_github_asset` over duplicating
  behavior.
- Preserve `--dry-run`, `--yes`, supported architecture checks, and explicit
  unsupported-platform errors.
- Keep installations repeatable and avoid duplicating user configuration.
- Validate every shell script with `shfmt` and `shellcheck`, and every
  Markdown file with `markdownlint-cli2`.
- Do not add `curl | sh` installation paths. Download release metadata and
  assets separately, validate expected values, and install with explicit
  permissions.
- Keep comments focused on non-obvious behavior. Update `README.md` for
  user-visible changes.

## Safety

The script changes system packages, installs binaries under `/usr/local`, may
enable Docker, and modifies the current user's Docker group and `.bashrc`.
Prefer dry-run validation and avoid executing the installer against a live
system during development unless explicitly required.
