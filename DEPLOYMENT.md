# Deployment Guide

This guide explains how to create a new release for the Create FusionHub on Proxmox project.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Version Numbering](#version-numbering)
- [Release Process](#release-process)
  - [Method 1: Using GitHub CLI (Recommended)](#method-1-using-github-cli-recommended)
  - [Method 2: Using GitHub Web Interface](#method-2-using-github-web-interface)
- [Post-Release Verification](#post-release-verification)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- Clean git working directory (no uncommitted changes)
- All changes pushed to the `main` branch
- Updated `CHANGELOG.md` with the new version details
- Updated `README.md` if there are new features or parameters

## Version Numbering

This project follows [Semantic Versioning](https://semver.org/):

- **Patch version (0.0.x)**: Bug fixes, documentation updates, minor improvements
- **Minor version (0.x.0)**: New features, backward-compatible changes
- **Major version (x.0.0)**: Breaking changes, major rewrites

## Release Process

### Method 1: Using GitHub CLI (Recommended)

#### Step 1: Install GitHub CLI

```bash
# macOS (using Homebrew)
brew install gh

# Linux (Debian/Ubuntu)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# Linux (Fedora/CentOS/RHEL)
sudo dnf install gh
```

#### Step 2: Authenticate with GitHub

```bash
gh auth login
```

Follow the prompts:
1. Select `GitHub.com`
2. Select `HTTPS` as the protocol
3. Select `Login with a web browser`
4. Copy the one-time code shown
5. Press Enter to open your browser
6. Paste the code and authorize

Verify authentication:
```bash
gh auth status
```

#### Step 3: Update Documentation

Update `CHANGELOG.md` with the new version:

```markdown
## [0.0.x] - YYYY-MM-DD

### Added
- List new features

### Changed
- List changes to existing features

### Fixed
- List bug fixes
```

Update `README.md` if there are new parameters or usage changes.

#### Step 4: Commit Documentation Changes

```bash
git add CHANGELOG.md README.md
git commit -m "docs: update CHANGELOG and README for vX.X.X release"
```

#### Step 5: Create Git Tag

```bash
# Replace X.X.X with your version number
git tag -a vX.X.X -m "Release vX.X.X: Brief Description

Detailed release notes:
- Feature 1
- Feature 2
- Bug fix 1

Full changelog: https://github.com/larrychannon/Create-Peplink-FusionHub-on-Proxmox/blob/main/CHANGELOG.md"
```

#### Step 6: Push Commits and Tag

```bash
# Push commits
git push origin main

# Push tag
git push origin vX.X.X
```

#### Step 7: Create GitHub Release

```bash
gh release create vX.X.X \
  --title "vX.X.X - Release Title" \
  --notes "## What's New

Brief description of the release.

### New Features
- Feature 1
- Feature 2

### Changes
- Change 1

### Bug Fixes
- Fix 1

### Full Changelog
See [CHANGELOG.md](https://github.com/larrychannon/Create-Peplink-FusionHub-on-Proxmox/blob/main/CHANGELOG.md)"
```

#### Step 8: Verify Release

```bash
# View the release
gh release view vX.X.X

# List all releases
gh release list
```

### Method 2: Using GitHub Web Interface

#### Step 1-4: Same as GitHub CLI Method

Follow steps 1-4 from the GitHub CLI method (you don't need to install `gh` for this method).

#### Step 5: Create Git Tag

```bash
git tag -a vX.X.X -m "Release vX.X.X: Brief Description"
```

#### Step 6: Push to GitHub

```bash
git push origin main
git push origin vX.X.X
```

#### Step 7: Create Release on GitHub

1. Go to: https://github.com/larrychannon/Create-Peplink-FusionHub-on-Proxmox/releases/new
2. **Choose a tag**: Select `vX.X.X` from the dropdown
3. **Release title**: Enter `vX.X.X - Release Title`
4. **Describe this release**: Add your release notes in markdown format:

```markdown
## 🎉 What's New

Brief description of the release.

### ✨ New Features

- Feature 1
- Feature 2

### 🔄 Changes

- Change 1

### 🐛 Bug Fixes

- Fix 1

### 📚 Documentation

- Documentation updates

### 📦 Full Changelog

See [CHANGELOG.md](https://github.com/larrychannon/Create-Peplink-FusionHub-on-Proxmox/blob/main/CHANGELOG.md) for complete details.
```

5. **Set as latest release**: Check this box (default)
6. Click **Publish release**

#### Step 8: Verify Release

Visit: https://github.com/larrychannon/Create-Peplink-FusionHub-on-Proxmox/releases

## Post-Release Verification

### 1. Check Release Page

```bash
# Using GitHub CLI
gh release view vX.X.X

# Or visit the URL
open https://github.com/larrychannon/Create-Peplink-FusionHub-on-Proxmox/releases/tag/vX.X.X
```

### 2. Verify Tag is Published

```bash
git fetch origin
git tag -l
git ls-remote --tags origin
```

### 3. Test Installation

On a Proxmox server, test the quick start command:

```bash
bash -c "$(wget -qLO - https://github.com/larrychannon/Create-Peplink-FusionHub-on-Proxmox/raw/main/create-fusionhub.sh)"
```

### 4. Check Release is Marked as "Latest"

```bash
gh release list --limit 5
```

The newest release should show "Latest" in the output.

## Troubleshooting

### GitHub CLI Not Found

**Problem**: `command not found: gh`

**Solution**: Install GitHub CLI using the instructions in Step 1.

### Authentication Failed

**Problem**: `You are not logged into any GitHub hosts`

**Solution**: Run `gh auth login` and follow the authentication steps.

### Tag Already Exists

**Problem**: `tag 'vX.X.X' already exists`

**Solution**:
```bash
# Delete local tag
git tag -d vX.X.X

# Delete remote tag
git push origin :refs/tags/vX.X.X

# Create new tag
git tag -a vX.X.X -m "Release notes"
```

### Repository Moved Warning

**Problem**: `remote: This repository moved. Please use the new location`

**Solution**: Update your remote URL:
```bash
git remote set-url origin https://github.com/larrychannon/Create-Peplink-FusionHub-on-Proxmox.git
```

### Release Creation Failed

**Problem**: `HTTP 422: Validation Failed`

**Solution**: Check that:
- The tag exists and has been pushed to GitHub
- You have write permissions to the repository
- The release doesn't already exist

## Example Release Notes Template

Use this template when creating releases:

```markdown
## 🎉 What's New

[Brief 1-2 sentence description of the release]

### ✨ New Features

- **Feature Name** - Description of what it does
- **Another Feature** - Description

### 🔄 Changes

- Changed behavior or updated functionality
- Enhanced or improved existing feature

### 🐛 Bug Fixes

- Fixed: Description of the bug fix
- Fixed: Another bug fix

### 📚 Documentation

- Updated README with new parameters
- Added usage examples
- Created/updated guides

### 📦 Full Changelog

See [CHANGELOG.md](https://github.com/larrychannon/Create-Peplink-FusionHub-on-Proxmox/blob/main/CHANGELOG.md) for complete details.

**Commits since vX.X.X:** [number] commits
```

## Quick Reference

### Common Commands

```bash
# Check authentication status
gh auth status

# List releases
gh release list

# View a specific release
gh release view vX.X.X

# Delete a release
gh release delete vX.X.X

# Edit a release
gh release edit vX.X.X --notes "Updated notes"

# Create a draft release
gh release create vX.X.X --draft --title "Title" --notes "Notes"

# Mark a release as latest
gh release edit vX.X.X --latest
```

### Git Tag Commands

```bash
# List all tags
git tag -l

# Show tag details
git show vX.X.X

# Delete local tag
git tag -d vX.X.X

# Delete remote tag
git push origin :refs/tags/vX.X.X

# Fetch all tags from remote
git fetch --tags
```

## Best Practices

1. **Always update CHANGELOG.md** before creating a release
2. **Use semantic versioning** for version numbers
3. **Write descriptive release notes** that explain what changed and why
4. **Test the script** before creating the release
5. **Create annotated tags** (with `-a` flag) instead of lightweight tags
6. **Keep release notes consistent** using the template provided
7. **Verify the release** after publishing
8. **Update documentation** (README, etc.) as part of the release process

## Resources

- [GitHub CLI Documentation](https://cli.github.com/manual/)
- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [GitHub Releases Guide](https://docs.github.com/en/repositories/releasing-projects-on-github)
