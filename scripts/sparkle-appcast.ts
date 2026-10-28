import { execFileSync } from 'child_process'
import { createHash } from 'crypto'
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync } from 'fs'
import { basename, join, resolve } from 'path'
import { fileURLToPath } from 'url'

const projectRoot = resolve(fileURLToPath(import.meta.url), '../..')
const keychainAccount = 'com.csl.cool.Shark'

function xmlValue(file: string, expression: string): string {
  return execFileSync('/usr/bin/xmllint', ['--nonet', '--xpath', expression, file], {
    encoding: 'utf-8',
  }).trim()
}

/** Stages a signed feed only after matching an archive to its public release bytes. */
export async function generateSparkleAppcast(
  version: string,
  archivePath: string,
  derivedData: string,
): Promise<string> {
  if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(version)) {
    throw new Error('A semantic release version is required')
  }
  const archive = resolve(archivePath)
  if (basename(archive) !== `SharkSpace-${version}.dmg` || !existsSync(archive)) {
    throw new Error(`Expected an existing SharkSpace-${version}.dmg`)
  }

  const tools = join(resolve(derivedData), 'SourcePackages/artifacts/sparkle/Sparkle/bin')
  for (const name of ['generate_keys', 'generate_appcast', 'sign_update']) {
    if (!existsSync(join(tools, name))) {
      throw new Error(`Missing ${name}; resolve the pinned Sparkle package in this DerivedData first`)
    }
  }
  const expectedKey = execFileSync('/usr/libexec/PlistBuddy', [
    '-c', 'Print :SUPublicEDKey', join(projectRoot, 'Shark/Info.plist'),
  ], { encoding: 'utf-8' }).trim()
  const publicKey = execFileSync(join(tools, 'generate_keys'), [
    '--account', keychainAccount, '-p',
  ], { encoding: 'utf-8' }).trim()
  if (!expectedKey || publicKey !== expectedKey) {
    throw new Error('The Keychain public key does not match SUPublicEDKey; do not rotate it implicitly')
  }

  const bytes = readFileSync(archive)
  const hash = createHash('sha256').update(bytes).digest('hex')
  const prefix = `https://github.com/SSBun/Shark/releases/download/v${version}/`
  const downloadURL = `${prefix}${basename(archive)}`
  const response = await fetch(downloadURL, { signal: AbortSignal.timeout(60_000) })
  if (response.status !== 200) {
    throw new Error(`Release asset is not public: HTTP ${response.status}`)
  }
  const publishedHash = createHash('sha256')
    .update(Buffer.from(await response.arrayBuffer())).digest('hex')
  if (publishedHash !== hash) {
    throw new Error('Local archive differs from the published asset; download the final release bytes first')
  }

  const outputRoot = join(projectRoot, 'dist')
  mkdirSync(outputRoot, { recursive: true })
  const staging = mkdtempSync(join(outputRoot, 'sparkle-appcast-'))
  try {
    const stagedArchive = join(staging, basename(archive))
    const feed = join(staging, 'appcast.xml')
    const previousFeed = join(projectRoot, 'docs/appcast.xml')
    cpSync(archive, stagedArchive)
    cpSync(previousFeed, feed)
    execFileSync(join(tools, 'generate_appcast'), [
      '--account', keychainAccount,
      '--download-url-prefix', prefix,
      '--maximum-deltas', '0',
      staging,
    ], { stdio: 'inherit' })

    const item = `/rss/channel/item[enclosure/@url="${downloadURL}"]`
    const build = Number(xmlValue(feed, `string(${item}/*[local-name()='version'])`))
    const shortVersion = xmlValue(feed, `string(${item}/*[local-name()='shortVersionString'])`)
    const length = Number(xmlValue(feed, `string(${item}/enclosure/@length)`))
    const signature = xmlValue(feed, `string(${item}/enclosure/@*[local-name()='edSignature'])`)
    if (!Number.isSafeInteger(build) || build <= 0 || shortVersion !== version || length !== bytes.length || !signature) {
      throw new Error('Generated item does not match the release version, integer build, length, or signature')
    }
    const previousCount = Number(xmlValue(previousFeed, 'count(/rss/channel/item)'))
    for (let index = 1; index <= previousCount; index++) {
      const previousBuild = Number(xmlValue(previousFeed,
        `string(/rss/channel/item[${index}]/*[local-name()='version'])`))
      if (!Number.isSafeInteger(previousBuild) || previousBuild <= 0 || build <= previousBuild) {
        throw new Error('CFBundleVersion must be an integer greater than every existing feed build')
      }
    }
    execFileSync(join(tools, 'sign_update'), [
      '--account', keychainAccount, '--verify', stagedArchive, signature,
    ], { stdio: 'inherit' })
    if (createHash('sha256').update(readFileSync(stagedArchive)).digest('hex') !== publishedHash) {
      throw new Error('Archive bytes changed while generating the feed')
    }
    return feed
  } catch (error) {
    rmSync(staging, { recursive: true, force: true })
    throw error
  }
}
