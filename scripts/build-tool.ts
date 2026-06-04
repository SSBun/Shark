#!/usr/bin/env tsx
// scripts/build-tool.ts — SharkSpace build, package & publish tool.
//
// Commands:
//   create-dmg [version]   Build app and package as DMG
//   publish <version>      Create DMG and publish to npm
//
// Options shared by both commands:
//   --no-build             Skip xcodebuild step
//   -s, --scheme <name>    Xcode scheme (default: "Shark")
//   -o, --output <dir>     Output directory (default: "dist")
//   --derived-data <path>  DerivedData path (default: "build")
//
// Usage:
//   tsx scripts/build-tool.ts create-dmg 1.9.0
//   tsx scripts/build-tool.ts create-dmg --no-build
//   tsx scripts/build-tool.ts publish 1.9.0
//   tsx scripts/build-tool.ts publish 1.9.0 --no-build --dry-run

import { Command } from 'commander'
import * as p from '@clack/prompts'
import { execSync } from 'child_process'
import {
  copyFileSync, cpSync, existsSync, mkdirSync, rmSync,
  writeFileSync, readFileSync,
} from 'fs'
import { tmpdir } from 'os'
import { basename, join, resolve } from 'path'
import { randomUUID, createHash } from 'crypto'
import { fileURLToPath } from 'url'

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const projectRoot = resolve(fileURLToPath(import.meta.url), '../..')

function capture(cmd: string): string | null {
  try {
    return execSync(cmd, { encoding: 'utf-8', stdio: 'pipe' }).trim()
  } catch {
    return null
  }
}

function exec(cmd: string): void {
  execSync(cmd, { encoding: 'utf-8', stdio: 'inherit' })
}

// ---------------------------------------------------------------------------
// Shared DMG creation
// ---------------------------------------------------------------------------

interface CreateDMGOpts {
  scheme: string
  build: boolean
  output: string
  derivedData: string
}

async function createDMG(
  version: string,
  opts: CreateDMGOpts,
): Promise<string> {
  const releaseVersion = version || process.env.npm_package_version || ''
  const outputDir = resolve(opts.output)
  const derivedData = resolve(opts.derivedData)

  // ---- 1. Build ----
  if (opts.build) {
    const spinner = p.spinner()
    spinner.start(`Building «${opts.scheme}» (Release)…`)
    try {
      execSync(
        `xcodebuild` +
        ` -scheme "${opts.scheme}"` +
        ` -configuration Release` +
        ` -derivedDataPath "${derivedData}"` +
        ` -destination 'platform=macOS'` +
        ` clean build`,
        { encoding: 'utf-8', stdio: 'pipe' },
      )
      spinner.stop('Build complete')
    } catch (e: any) {
      const msg = (e.stderr?.toString()?.trim() || e.message || '')
        .split('\n').slice(-5).join('\n')
      spinner.stop('Build failed')
      p.cancel(`xcodebuild failed:\n${msg}`)
      process.exit(1)
    }
  } else {
    p.log.info('Skipping build (--no-build)')
  }

  // ---- 2. Locate .app ----
  const appPath = capture(`find "${derivedData}" -name "*.app" -type d | head -1`)
  if (!appPath) {
    p.cancel(
      'No .app found in DerivedData.\n' +
      '  Did you build? Use --no-build if pre-built elsewhere\n' +
      '  and point --derived-data at the parent folder.',
    )
    process.exit(1)
  }
  const appName = basename(appPath)
  p.log.success(`Found: ${appPath}`)

  // ---- 3. Stage files ----
  const tmpDir = join(tmpdir(), `sharkspace-dmg-${randomUUID()}`)
  mkdirSync(tmpDir, { recursive: true })
  cpSync(appPath, join(tmpDir, appName), { recursive: true })

  writeFileSync(join(tmpDir, 'INSTALL.md'), [
    '# SharkSpace Installation Guide',
    '',
    '## Quick Install',
    '1. Drag **SharkSpace.app** into the **Applications** folder.',
    '2. Open Terminal and run:',
    '   ```',
    '   xattr -cr /Applications/SharkSpace.app',
    '   ```',
    '3. Launch SharkSpace from Applications.',
    '',
    '## Why `xattr`?',
    'macOS adds quarantine attributes to downloaded applications.',
    'The command above removes them so the app can launch.',
    '',
  ].join('\n'))

  // ---- 4. Create DMG ----
  mkdirSync(outputDir, { recursive: true })
  const dmgName = releaseVersion
    ? `SharkSpace-${releaseVersion}.dmg`
    : 'SharkSpace.dmg'
  const dmgPath = join(outputDir, dmgName)

  if (existsSync(dmgPath)) rmSync(dmgPath)
  capture(`rm -f rw.*.${dmgName}`)

  const spinner = p.spinner()
  spinner.start('Creating DMG…')

  const hasCreateDmg = capture('command -v create-dmg')

  if (hasCreateDmg) {
    p.log.info('Using create-dmg (visual layout)')
    capture(
      `create-dmg` +
      ` --volname "SharkSpace"` +
      ` --window-pos 200 120` +
      ` --window-size 600 400` +
      ` --icon-size 100` +
      ` --icon "${appName}" 175 190` +
      ` --hide-extension "${appName}"` +
      ` --app-drop-link 425 190` +
      ` --no-internet-enable` +
      ` "${dmgPath}"` +
      ` "${tmpDir}"`,
    )
  }

  if (!existsSync(dmgPath)) {
    if (!hasCreateDmg) p.log.info('create-dmg not found — using hdiutil fallback')
    capture(`ln -s /Applications "${join(tmpDir, 'Applications')}"`)
    exec(
      `hdiutil create` +
      ` -volname "SharkSpace"` +
      ` -srcfolder "${tmpDir}"` +
      ` -ov` +
      ` -format UDZO` +
      ` "${dmgPath}"`,
    )
  }

  spinner.stop('DMG created')

  // ---- 5. Cleanup ----
  rmSync(tmpDir, { recursive: true, force: true })
  capture(`rm -f rw.*.${dmgName}`)

  // ---- 6. Checksum & stable path ----
  const hash = createHash('sha256').update(readFileSync(dmgPath)).digest('hex')
  writeFileSync(`${dmgPath}.sha256`, `${hash}  ${dmgName}\n`)

  const stableDmg = join(projectRoot, 'SharkSpace.dmg')
  copyFileSync(dmgPath, stableDmg)
  writeFileSync(`${stableDmg}.sha256`, `${hash}  SharkSpace.dmg\n`)

  // ---- 7. Summary ----
  const mb = (readFileSync(dmgPath).length / 1024 / 1024).toFixed(1)
  p.note(`${dmgPath}  (${mb} MB)`, '📀 DMG')
  p.note(hash, '🔐 SHA-256')

  return dmgPath
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

const program = new Command()
  .name('build-tool')
  .description('SharkSpace build, package & publish tool')

// ---- create-dmg ----------------------------------------------------------
program
  .command('create-dmg')
  .description('Build SharkSpace and package it as a DMG')
  .argument('[version]', 'release version (default: pkg.version, no suffix if omitted)')
  .option('--no-build', 'skip xcodebuild')
  .option('-s, --scheme <name>', 'Xcode scheme', 'Shark')
  .option('-o, --output <dir>', 'output directory', 'dist')
  .option('--derived-data <path>', 'DerivedData path', 'build')
  .action(async (version, opts) => {
    p.intro('📦  SharkSpace DMG Builder')
    await createDMG(version, {
      scheme: opts.scheme,
      build: opts.build,
      output: opts.output,
      derivedData: opts.derivedData,
    })
    const fileName = version ? `SharkSpace-${version}.dmg` : 'SharkSpace.dmg'
    p.outro(`Done → ${join(resolve(opts.output), fileName)}`)
  })

// ---- publish -------------------------------------------------------------
program
  .command('publish')
  .description('Bump version, create DMG, and publish to npm')
  .argument('<version>', 'release version (required, e.g. 1.9.0)')
  .option('--no-build', 'skip xcodebuild (reuse existing .app)')
  .option('-s, --scheme <name>', 'Xcode scheme', 'Shark')
  .option('-o, --output <dir>', 'output directory', 'dist')
  .option('--derived-data <path>', 'DerivedData path', 'build')
  .option('--tag <dist-tag>', 'npm dist-tag', 'latest')
  .option('--access <access>', 'npm access level', 'public')
  .option('--dry-run', 'dry-run everything (no actual publish)')
  .option('--otp <code>', 'npm OTP code for publishing')
  .action(async (version, opts) => {
    p.intro('🚀  SharkSpace Publish')

    // ---- Bump package.json ----
    const pkgPath = join(projectRoot, 'package.json')
    const pkg = JSON.parse(readFileSync(pkgPath, 'utf-8'))
    pkg.version = version
    writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n')
    p.log.success(`Version bumped to ${version}`)

    // ---- Create DMG ----
    await createDMG(version, {
      scheme: opts.scheme,
      build: opts.build,
      output: opts.output,
      derivedData: opts.derivedData,
    })

    // ---- Publish ----
    const dryRun = opts.dryRun ? '--dry-run' : ''
    const otpFlag = opts.otp ? `--otp ${opts.otp}` : ''
    const pubSpinner = p.spinner()
    pubSpinner.start(`npm publish${dryRun ? ' (dry-run)' : ''}…`)
    const pub = capture(
      `npm publish ${dryRun} --access ${opts.access} --tag ${opts.tag} ${otpFlag}`.trim(),
    )
    if (pub === null) {
      pubSpinner.stop('Publish failed')
      p.cancel('npm publish failed. Check npm authentication and try again.')
      process.exit(1)
    }
    pubSpinner.stop('Published to npm')
    if (pub) p.log.info(pub)

    p.outro(`Published @ssbun/sharkspace@${version}${dryRun ? ' (dry-run)' : ''}`)
  })

program.parse(process.argv)
