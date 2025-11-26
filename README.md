# Command Mock Framework

[![PyPI version](https://badge.fury.io/py/orgecc-command-mock.svg)](https://badge.fury.io/py/orgecc-command-mock)
[![Tests](https://github.com/elifarley/command-mock/actions/workflows/test.yml/badge.svg)](https://github.com/elifarley/command-mock/actions/workflows/test.yml)

**High-fidelity, deterministic command mocking for Python tests.**

Stop mocking `subprocess.run` with invented strings. Record real command outputs once, store them in version control, and replay them during tests.

---

## The Problem

Testing code that wraps CLI tools (Git, Docker, Kubectl, npm) is painful.
- **Manual mocks are brittle:** You guess what `git log` returns, but you get it wrong.
- **Real commands are slow:** Running `docker ps` in every test kills performance.
- **Integration tests are flaky:** Environments change, causing non-deterministic failures.

## The Solution

**Command Mock Framework** sits between your code and `subprocess`.
1. **Record** real command outputs to TOML files.
2. **Replay** them instantly in tests.
3. **Match** commands flexibly using template placeholders.

### Quick Example

**1. Record the real behavior:**
```python
from command_mock.recorder import CommandMockRecorder

# Run this once to generate 'mocks/git/log/follow.toml'
recorder = CommandMockRecorder("git")
recorder.record_scenario(
    command=["git", "log", "--follow", "--", "{filepath}"],
    scenario_name="basic_history",
    template_vars={"filepath": "app.py"}
)
```

**2. Use it in your test:**
```python
def test_get_history(command_mock):
    # Load the mock (command_mock is a pytest fixture)
    mock_fn = command_mock.get_subprocess_mock("log/follow.toml", "basic_history")

    # Patch subprocess.run
    with patch('subprocess.run', side_effect=mock_fn):
        # This executes FAST and returns REAL git output
        # It matches 'git log ... -- app.py' OR 'git log ... -- other.py'
        history = my_git_wrapper.get_history("app.py")

    assert len(history) == 5
```

## Installation

```bash
pip install orgecc-command-mock
```

## Usage Guide

### 1. Setup

Add the pytest plugin to your conftest.py:

```python
# tests/conftest.py
import pytest
from pathlib import Path
from command_mock.recorder import CommandMockRecorder
from command_mock.player import CommandMockPlayer

@pytest.fixture
def command_mock(request):
    """Fixture that switches between Player (default) and Recorder."""
    # Point this to where you want to store your TOML files
    fixtures_root = Path(__file__).parent

    if request.config.getoption("--regenerate-mocks"):
        return CommandMockRecorder("git", fixtures_root=fixtures_root)
    else:
        return CommandMockPlayer("git", fixtures_root=fixtures_root)

def pytest_addoption(parser):
    parser.addoption("--regenerate-mocks", action="store_true", help="Record new mocks")
```

### 2. Recording Mocks

Create a script (e.g., tests/generate_mocks.py) to generate your test data. This ensures your mocks are reproducible.

```python
from command_mock.recorder import CommandMockRecorder

def generate():
    recorder = CommandMockRecorder("git")

    # You can even use setup scripts to create real repo states!
    repo = recorder.create_test_repo("scripts/setup_repo.sh")

    recorder.record_scenario(
        command=["git", "status"],
        scenario_name="clean_state",
        output_path="status/clean.toml",
        repo_path=repo
    )

if __name__ == "__main__":
    generate()
```

### 3. Flexible Matching

This is the framework's superpower. You don't need a mock for every single argument variation. Use placeholders in your templates.

**Embedded Placeholders:**
```python
# Template in TOML:
command = ["git", "log", "--grep={term}"]

# Matches all of these in tests:
["git", "log", "--grep=fix"]
["git", "log", "--grep=feat"]
```

**Standalone Placeholders:**
```python
# Template in TOML:
command = ["git", "add", "{filepath}"]

# Matches all of these in tests:
["git", "add", "src/main.py"]
["git", "add", "tests/test_core.py"]
```

**Dynamic Flag Stripping:**
The player automatically handles flags that change every run (like `--since="1 hour ago"`), matching the core command while ignoring the dynamic parts.

## Development

This project uses a Makefile for all development tasks.

```bash
make install      # Install dev dependencies
make test         # Run tests
make format       # Format code (Black/Ruff)
make ci           # Run full CI suite locally
```

For detailed contribution guidelines, see [CLAUDE.md](CLAUDE.md).

## License

Apache 2.0
