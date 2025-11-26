# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**command-mock-framework** is a high-fidelity command mocking library for Python testing. It allows developers to record real command outputs (git, docker, npm, etc.) to TOML files and replay them as mocks in tests, ensuring tests are deterministic and fast without sacrificing realism.

**Key Architecture:**
- **Recorder** (`recorder.py`): Captures real command execution output to TOML files with metadata
- **Player** (`player.py`): Loads TOML mocks and provides `subprocess.run` mocks with flexible command matching
- **pytest Plugin** (`conftest.py`): Fixtures and CLI flags (`--regenerate-mocks`, `--command-type`) for test integration

## Development Commands

All development tasks use the **Makefile** (see `make help` for full list):

### Setup & Installation
```bash
make install          # Install package + dev dependencies (editable mode)
make dev             # Alias for install
```

### Code Quality
```bash
make format          # Auto-format code (black + ruff fix)
make check-format    # Check formatting (read-only, used in CI)
make lint            # Run ruff + mypy static analysis
make ci              # Full CI chain: check-format → lint → test
```

### Testing
```bash
make test            # Run tests with coverage (html + terminal)
make quick           # Run tests without coverage (faster)
make test-file FILE=path/to/test.py
make test-case K=pattern     # e.g., K=test_exact_match
make coverage-open   # Open HTML coverage report in browser
```

### Building & Releases
```bash
make build           # Build wheel + sdist (cleans first)
make clean           # Remove build artifacts, __pycache__, caches
make distclean       # Aggressive clean (includes .venv, tool caches)
```

## Architecture Details

### Core Components

**CommandMockRecorder** (`src/command_mock/recorder.py`)
- Executes real commands and captures output to TOML files
- Supports template placeholders in commands: `["git", "log", "--grep={term}"]`
- Stores output in separate `.txt` files relative to TOML for modularity
- Handles binary output gracefully (reports fatal error, doesn't crash)
- Key methods:
  - `record_scenario()`: Execute command, store template + output
  - `record_multiple_scenarios()`: Batch recording with repo setup scripts
  - `generate_mock_file()`: Write TOML with scenarios

**CommandMockPlayer** (`src/command_mock/player.py`)
- Loads TOML mock files and provides `subprocess.run` mocks
- Flexible command matching: supports embedded placeholders (`--grep={term}`) and standalone placeholders (`{filepath}`)
- Dynamic flags stripped during matching (e.g., `--since` added by application code)
- Cache scenarios to avoid repeated TOML parsing
- Key methods:
  - `get_subprocess_mock()`: Returns a mock function for `patch('subprocess.run')`
  - `command_matches()`: Flexible template matching with placeholder support
  - `load_scenarios()`: Load and cache TOML scenarios

**pytest Plugin** (`tests/conftest.py`)
- Provides `command_mock` fixture (returns Recorder or Player)
- CLI flags:
  - `--regenerate-mocks`: Use Recorder to regenerate all mock data
  - `--command-type`: Specify command category (git, docker, npm, etc.)

### Mock File Structure

Mocks live in `tests/mocks/<command_type>/<path>/<file>.toml`:
```toml
[[scenario]]
name = "basic"
description = "File history without filters"
command = ["git", "log", "--follow", "--format=%H|%an|%ai", "--", "{filepath}"]
returncode = 0
output_file = "outputs/follow-basic.txt"
stderr = ""
```

Output files stored separately: `tests/mocks/<command_type>/<path>/outputs/<name>.txt`

## Dependencies & Versioning

**Dynamic Versioning with setuptools_scm:**
- Version is derived from git tags (e.g., `0.1.0`, `1.0.0`)
- No hardcoded version in code; git tag is source of truth
- Build system: `setuptools>=61.0`, `setuptools_scm>=8.0`

**Python Support:** `>=3.8`

**Runtime Dependencies:**
- `tomli` (< 3.11): TOML parsing for older Python
- `tomli-w`: TOML writing for mock generation

**Dev Dependencies:** (installed with `make install`)
- `black`, `ruff`: Code formatting & linting
- `mypy`: Static type checking
- `pytest`, `pytest-cov`: Testing & coverage

## Release Workflow

**Tag Format:** Semver without `v` prefix (e.g., `0.1.0`, `0.1.1`, `1.0.0`)

Releases are triggered by pushing git tags matching `*.*.*` pattern. The workflow automatically runs tests, builds distributions, publishes to PyPI via Trusted Publishing (OIDC), and creates GitHub Releases.

For detailed release instructions and troubleshooting, see [CONTRIBUTING.md](CONTRIBUTING.md).

## CI/CD

**Test Workflow** (`.github/workflows/test.yml`):
- Triggers on push to main/develop and pull requests
- Tests on Python 3.12 & 3.13
- Caches mypy/ruff/pytest between runs
- Runs: `make ci` (format check → lint → test with coverage)

**Release Workflow** (`.github/workflows/release.yml`):
- Triggered by pushing a semver tag
- Calls test workflow as pre-release check
- Publishes to PyPI with Trusted Publishing (OIDC)
- Creates GitHub Release with artifacts

## Key Decisions & Patterns

1. **Makefile-driven development**: All tasks (format, test, build) go through Makefile targets. This ensures local development matches CI exactly.

2. **Flexible command matching**: Templates can have embedded placeholders (`--grep={term}`) or standalone placeholders (`{filepath}`), allowing mocks to match variations of the same command pattern.

3. **Separate output files**: TOML stores only metadata; outputs live in separate `.txt` files. This keeps TOML readable and supports large output volumes.

4. **Single source of truth (git tags)**: Version is not in code; git tags are the versioning system. Enables clean releases and prevents version drift.

5. **Trusted Publishing**: Uses OIDC for PyPI authentication instead of tokens in secrets. More secure and modern approach.

## Common Patterns for New Features

**Adding support for a new command type:**
1. Create tests in `tests/test_<command>.py`
2. Create test fixtures in `tests/mocks/<command_type>/...`
3. Use `command_mock` fixture with `command_type=<type>` parameter
4. Tests work in both mock (default) and regeneration mode (`--regenerate-mocks`)

**Extending mock matching logic:**
- Edit `command_matches()` in `player.py` to handle new placeholder patterns
- Add test cases to `TestMatchingLogic` in `tests/test_core.py`
- Ensure backward compatibility with existing placeholder formats
