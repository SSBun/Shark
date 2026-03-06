# Release Checklist

Follow these steps to release a new version of Shark.

## 1. Update Version in Xcode Project

Before building, update the version numbers in `Shark.xcodeproj/project.pbxproj`:

```bash
# Update MARKETING_VERSION (e.g., 1.1.4)
sed -i '' 's/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = X.X.X;/g' Shark.xcodeproj/project.pbxproj

# Update CURRENT_PROJECT_VERSION (build number, e.g., 4)
sed -i '' 's/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = N;/g' Shark.xcodeproj/project.pbxproj
```

Verify the changes:
```bash
grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" Shark.xcodeproj/project.pbxproj
```

## 2. Build the Code

Build the project using Xcode:

```bash
# Option 1: Build via command line
xcodebuild -project Shark.xcodeproj -scheme Shark -configuration Release build
```

Or open in Xcode and build with `Cmd + B`, then archive with `Cmd + Shift + E`.

## 3. Verify Build

- Check the build succeeded without errors
- Verify the app version shows correctly in Settings > About tab
- Test basic functionality

## 4. Create Version Tag

Create and push a git tag with the version number:

```bash
# Create tag (use v prefix, e.g., v1.1.4)
git tag -a vX.X.X -m "Release vX.X.X"

# Push tag to remote
git push origin vX.X.X
```

## 5. Verify GitHub Action

- Go to [GitHub Actions](https://github.com/SSBun/Shark/actions)
- Check the release workflow is running
- Verify the DMG is uploaded to the release

## 6. Verify Release

- Check the release is created at https://github.com/SSBun/Shark/releases
- Verify the DMG file is attached
- Test the install script works:
  ```bash
  curl -sL https://github.com/SSBun/Shark/raw/main/install_latest.sh | bash
  ```

---

## Quick Reference

| Step | Command |
|------|---------|
| Update version | `sed -i '' 's/MARKETING_VERSION = .*/MARKETING_VERSION = X.X.X;/g' Shark.xcodeproj/project.pbxproj` |
| Update build | `sed -i '' 's/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = N;/g' Shark.xcodeproj/project.pbxproj` |
| Build | `xcodebuild -project Shark.xcodeproj -scheme Shark -configuration Release build` |
| Create tag | `git tag -a vX.X.X -m "Release vX.X.X"` |
| Push tag | `git push origin vX.X.X` |
