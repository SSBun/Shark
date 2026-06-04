# Release Checklist

Follow these steps to release a new version of SharkSpace.

## 1. Create a Release Branch

```bash
git checkout -b release/vX.X.X
```

## 2. Update Version in Xcode Project

Update the version numbers in `Shark.xcodeproj/project.pbxproj`:

```bash
# Update MARKETING_VERSION (e.g., 1.9.0)
sed -i '' 's/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = X.X.X;/g' Shark.xcodeproj/project.pbxproj

# Update CURRENT_PROJECT_VERSION (build number, e.g., 10)
sed -i '' 's/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = N;/g' Shark.xcodeproj/project.pbxproj
```

Verify the changes:
```bash
grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" Shark.xcodeproj/project.pbxproj
```

## 3. Update Documentation

- Add changelog entry to `CHANGELOG.md`
- Update README.md if needed

## 4. Build & Package

Build the app and create a DMG using the build-tool:

```bash
# Build + create DMG
npx tsx scripts/build-tool.ts create-dmg X.X.X
```

Or skip the build step if you already have a built .app:

```bash
npx tsx scripts/build-tool.ts create-dmg X.X.X --no-build
```

## 5. Verify Build

- Check the build succeeded without errors
- Verify the app version shows correctly in Settings > About tab
- Test basic functionality
- DMG is at `dist/SharkSpace-X.X.X.dmg`

## 6. Create Version Tag

Create and push a git tag with the version number:

```bash
# Create tag (use v prefix, e.g., v1.9.0)
git tag -a vX.X.X -m "Release vX.X.X"

# Push tag to remote
git push origin vX.X.X
```

## 7. Publish to npm

Publish the DMG to npm:

```bash
npx tsx scripts/build-tool.ts publish X.X.X --no-build
```

This bumps `package.json`, re-creates the DMG, and runs `npm publish --access public`.

During publish you'll need npm OTP if 2FA is enabled:

```bash
npx tsx scripts/build-tool.ts publish X.X.X --no-build --otp 123456
```

## 8. Verify GitHub Action

- Go to [GitHub Actions](https://github.com/SSBun/Shark/actions)
- Check the release workflow is running
- Verify the DMG is uploaded to the release

## 9. Verify Release

- Check the release is created at https://github.com/SSBun/Shark/releases
- Verify the DMG file is attached
- Test the install script works:
  ```bash
  npx @ssbun/sharkspace shark
  ```

---

## Quick Reference

| Step | Command |
|------|---------|
| Update version | `sed -i '' 's/MARKETING_VERSION = .*/MARKETING_VERSION = X.X.X;/g' Shark.xcodeproj/project.pbxproj` |
| Update build | `sed -i '' 's/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = N;/g' Shark.xcodeproj/project.pbxproj` |
| Build + DMG | `npx tsx scripts/build-tool.ts create-dmg X.X.X` |
| Publish | `npx tsx scripts/build-tool.ts publish X.X.X --no-build --otp CODE` |
| Create tag | `git tag -a vX.X.X -m "Release vX.X.X"` |
| Push tag | `git push origin vX.X.X` |
