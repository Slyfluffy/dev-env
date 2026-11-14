# dev-env

Bootstrapping scripts for setting up a personalized development environment.

## Usage

Run [setup.bash](./setup.bash) on a supported Ubuntu or OpenSUSE system:

```bash
./setup.bash
```

The script presents an interactive menu. Select one or more numbered toolsets,
or choose `all`:

| Toolset | Installs |
| --- | --- |
| General | Git, wget, nano, pre-commit, and a colored Git-aware prompt |
| Bash | ShellCheck, shfmt, and bats-core |
| Python | Python 3, uv, Ruff, pytest, and pytest-cov |
| Go | Go |
| Containers | Docker, Docker Compose, Hadolint, Dockerfmt, and Cosign |
| Kubernetes | kubectl and Minikube |
| Markdown | Node.js/npm and markdownlint-cli2 |

## Options

```bash
./setup.bash --dry-run  # Show actions without changing the system
./setup.bash --yes      # Skip the package-install confirmation
./setup.bash --help     # Show command-line help
```

Toolset selection remains interactive even when `--yes` is supplied.

## Installation behavior

- Ubuntu uses `apt` and Docker's official APT repository.
- OpenSUSE uses `zypper`; Docker Compose is downloaded upstream when needed.
- The General toolset installs `pre-commit` from the distribution package
  (`python313-pre-commit` on OpenSUSE).
- The Markdown toolset installs `markdownlint-cli2` globally through npm.
- The current user is added to the `docker` group; start a new login session
  before using Docker without `sudo`.
- Latest upstream releases are downloaded for `kubectl`, Minikube, shfmt,
  Hadolint, Cosign, uv, and Docker Compose.
- Dockerfmt is built from the latest `reteps/dockerfmt` source.
- Supported CPU architectures are x86_64/AMD64 and ARM64.
- The script installs system-wide binaries under `/usr/local/bin`.
- Existing Bash prompt configuration is preserved. The managed prompt block is
  added only once to the current user's `~/.bashrc`.

Run the script again to install another toolset; package installation and
prompt configuration are safe to repeat.

Use `--dry-run` to inspect the commands first, or `--yes` to skip the
confirmation prompt. The script downloads the latest upstream releases of
Kubernetes, Python, and linting tools, and configures a Git-aware colored Bash
prompt when the corresponding toolset is selected.

## Pre-commit hooks

Install the repository hooks after installing the General and Bash toolsets:

```bash
pre-commit install
pre-commit run --all-files
```

The hooks run `shfmt` and `shellcheck` on shell scripts and verify final
newlines in repository files.
