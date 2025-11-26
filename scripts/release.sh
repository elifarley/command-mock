#!/usr/bin/env bash
set -e

# scripts/release.sh
# Handles the git tagging and pushing for a new release.
# Usage: ./scripts/release.sh <version>

VERSION="$1"

# 1. Validation
if [ -z "$VERSION" ]; then
    echo "Error: V argument is required."
    echo "Usage: make release V=1.2.3"
    exit 1
fi

# Validate SemVer format (X.Y.Z, no 'v' prefix)
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+)?$ ]]; then
    echo "Error: Version '$VERSION' does not match SemVer format (X.Y.Z)."
    echo "Example: 1.0.0, 0.2.1-rc1"
    exit 1
fi

# Check for clean working directory
if [ -n "$(git status --porcelain)" ]; then
    echo "Error: Git working directory is not clean."
    echo "Please commit or stash changes before releasing."
    exit 1
fi

# Check if tag already exists
if git rev-parse "refs/tags/$VERSION" >/dev/null 2>&1; then
    echo "Error: Tag '$VERSION' already exists."
    exit 1
fi

# 2. Execution
echo "Preparing release $VERSION..."

# Create annotated tag
git tag -a "$VERSION" -m "Release $VERSION"
echo "✅ Created git tag: $VERSION"

# Push tag
echo "Pushing tag to origin..."
git push origin "$VERSION"
echo "✅ Pushed tag to origin"

echo "🚀 Release $VERSION triggered! Check GitHub Actions for progress."
