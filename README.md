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

**Command Mock Framework** is a VCR-style library for `subprocess.run`. It sits between your code and `subprocess`.
1. **Record** real command outputs to TOML files.
2. **Replay** them instantly in tests.
3. **Match** commands flexibly using template placeholders.

Easily mock complex tools like **AWS CLI**, **Kubectl**, **Terraform**, and **Git** without manually constructing stdout strings.

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

---

## Alternatives & Philosophy

The **Command Mock Framework** occupies a specific niche: it applies the **VCR/Record-Replay pattern** (popularized by HTTP tools like `vcrpy`) to **subprocess/CLI calls**.

**Stop using `unittest.mock.patch` with fake stdout strings.** This framework guarantees fidelity by recording reality first.

Here is how it compares to other tools in the Python ecosystem:

### 1. The Direct Competitor: `pytest-subprocess`
This is the most popular modern library for this task. It allows you to define expected commands and outputs inside your test code.
*   **pytest-subprocess:** Best for **Code-Driven** testing. Excellent for defining logic flows (e.g., "if command X runs, return exit code 1").
*   **command-mock:** Best for **Data-Driven** testing. It separates test data (TOML) from test logic. It shines when output is verbose or structured (like `git log` or `docker inspect`) and you want to version-control the exact output snapshot.

### 2. The Standard Library: `unittest.mock`
The "vanilla" way that this framework was built to replace.
*   **unittest.mock:** Often leads to brittle tests. You have to manually invent stdout strings, which means your tests might pass while the real app fails because your invented string wasn't quite right.
*   **command-mock:** Guarantees fidelity by recording reality first.

### 3. "Real Execution" Tools (`cram`, `scripttest`)
These tools run actual shell commands in a sandbox.
*   **cram:** Provides 100% realism but is **slow** and requires a full environment setup (installing git, docker, etc. on the test runner).
*   **command-mock:** Replays instantly (`⚡ Fast`) and requires no external tools installed in the CI environment.

### 4. The HTTP Equivalent: `vcrpy`
If your CLI tool is primarily a wrapper around an API (e.g., a custom AWS wrapper), you might be mocking the wrong layer.
*   **Strategy:** Instead of mocking the subprocess call to `aws-cli`, use the Python SDK (`boto3`) and use `vcrpy` to record the HTTP interactions. Use **command-mock** when you must shell out to a binary.

### Summary

| Feature | **command-mock** | **pytest-subprocess** | **unittest.mock** | **cram** |
| :--- | :--- | :--- | :--- | :--- |
| **Primary Goal** | High-fidelity Replay | Programmatic Logic | Basic Mocking | Integration Testing |
| **Data Storage** | External Files (TOML) | In Python Code | In Python Code | Shell Transcript Files |
| **Realism** | ⭐⭐⭐⭐ (Recorded) | ⭐⭐ (Manual) | ⭐ (Manual) | ⭐⭐⭐⭐⭐ (Real) |
| **Speed** | ⚡ Fast | ⚡ Fast | ⚡ Fast | 🐢 Slow |
| **Best For** | Complex outputs | Logic flows, exit codes | Simple commands | End-to-end flows |

**Conclusion:**
If you need to mock complex tools like **Git**, **Docker**, or **Kubectl** where the stdout is verbose and structured, **command-mock** is the best fit because managing those massive strings inside Python code is messy and error-prone.

---

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
