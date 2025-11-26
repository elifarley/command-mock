# Contributing to Command Mock Framework

Thank you for your interest in contributing! This document covers development, testing, and release procedures.

## Development Workflow

### Setup

```bash
# Clone and enter the repository
git clone https://github.com/elifarley/command-mock.git
cd command-mock

# Install dev dependencies
make install
```

### Common Tasks

**Run tests with coverage:**
```bash
make test
```

**Run tests without coverage (faster):**
```bash
make quick
```

**Run a specific test:**
```bash
make test-case K=test_exact_match
```

**Format code:**
```bash
make format        # Auto-fix formatting
make check-format  # Check without modifying
```

**Run linting & type checks:**
```bash
make lint
```

**Run full CI pipeline locally:**
```bash
make ci            # check-format → lint → test
```

**Clean build artifacts:**
```bash
make clean         # Remove __pycache__, .pytest_cache, build/, dist/
make distclean      # Also remove .venv, .mypy_cache, .ruff_cache
```

For all available targets, run:
```bash
make help
```

## Submitting Changes

1. **Create a branch** for your feature or fix:
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make your changes** and test locally:
   ```bash
   make ci   # Ensure everything passes
   ```

3. **Commit with a clear message:**
   ```bash
   git commit -m "Add feature X: Brief description"
   ```

4. **Push and open a pull request** on GitHub.

## Releasing a New Version

### Step 1: Prepare Changes

Ensure all changes are committed and pushed to main:
```bash
git add .
git commit -m "Your changes here"
git push origin main
```

GitHub Actions will run the test suite automatically on your commits.

### Step 2: Create and Push a Version Tag

Use semantic versioning **without** the `v` prefix:

```bash
# Create an annotated tag
git tag 0.1.3 -m "Release 0.1.3: Description of changes"

# Push the tag to GitHub
git push origin 0.1.3
```

Examples of valid tags:
- `0.1.0` - Patch release
- `0.2.0` - Minor release
- `1.0.0` - Major release
- `1.0.0-rc1` - Release candidate

### Step 3: Automated Workflow

When you push a tag, GitHub Actions automatically:

1. **Triggers** `.github/workflows/release.yml`
2. **Runs pre-release checks** on Python 3.12 & 3.13
3. **Builds** distribution (wheel + sdist)
   - `setuptools_scm` auto-injects the version from the git tag
4. **Publishes to PyPI** using Trusted Publishing (OIDC)
5. **Creates a GitHub Release** with auto-generated notes and artifacts

### Step 4: Verify the Release

After 1-2 minutes, verify:

- **GitHub Actions:** https://github.com/elifarley/command-mock/actions
  - Release workflow should show ✅ success
- **PyPI:** https://pypi.org/project/orgecc-command-mock/
  - New version should be visible
- **GitHub Releases:** https://github.com/elifarley/command-mock/releases
  - Release entry with auto-generated notes should appear

## Troubleshooting Releases

### Release Failed - Tests Didn't Pass

Check the GitHub Actions log for details. Fix the failing tests and re-tag:

```bash
# Delete the failed tag
git tag -d 0.1.3
git push origin :refs/tags/0.1.3

# Fix the code
# ... make changes, commit, push ...

# Re-tag and try again
git tag 0.1.3 -m "Release 0.1.3: Fixed tests"
git push origin 0.1.3
```

### Trusted Publishing Not Configured

If you see an error about "invalid-publisher", Trusted Publishing needs to be set up on PyPI:

1. Go to https://pypi.org/project/orgecc-command-mock/
2. Navigate to **Project settings** → **Publishing**
3. Add GitHub as a trusted publisher:
   - **Repository name:** elifarley/command-mock
   - **Environment name:** pypi
   - **Workflow name:** release.yml

### Need to Re-Release the Same Version

If you need to modify and re-release the same version number:

```bash
# Delete the tag locally and remotely
git tag -d 0.1.3
git push origin :refs/tags/0.1.3

# Make your changes, commit, and push
git add .
git commit -m "Fix for 0.1.3"
git push origin main

# Re-create and push the tag
git tag 0.1.3 -m "Release 0.1.3: Updated"
git push origin 0.1.3
```

## Architecture & Development Notes

- See [CLAUDE.md](CLAUDE.md) for architecture details and core components
- See [README.md](README.md) for user-facing documentation
- Core modules: `src/command_mock/recorder.py`, `src/command_mock/player.py`
- Tests: `tests/test_core.py`, fixtures in `tests/conftest.py`
- Mock data stored in: `tests/mocks/<command_type>/`

## Questions?

Open an issue on GitHub or check the [README.md](README.md) and [CLAUDE.md](CLAUDE.md) for more information.
