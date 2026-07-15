#!/usr/bin/env node
const { execFile } = require("child_process");
const { writeFileSync, mkdtempSync } = require("fs");
const { tmpdir } = require("os");
const { join } = require("path");
const pkg = require("./package.json");

const dmgUrl = `https://github.com/SSBun/Shark/releases/download/v${pkg.version}/SharkSpace-${pkg.version}.dmg`;
const dmgPath = join(
  mkdtempSync(join(tmpdir(), "SharkSpace-")),
  `SharkSpace-${pkg.version}.dmg`
);

async function install() {
  console.log(`Downloading SharkSpace ${pkg.version}...`);
  const response = await fetch(dmgUrl);

  if (!response.ok) {
    throw new Error(`Download failed: ${response.status} ${dmgUrl}`);
  }

  writeFileSync(dmgPath, Buffer.from(await response.arrayBuffer()));
  console.log("Opening SharkSpace DMG...");
  console.log("Drag SharkSpace to Applications to install.\n");

  execFile("open", [dmgPath], (err) => {
    if (err) {
      console.error("Failed to open DMG:", err.message);
      process.exitCode = 1;
    }
  });
}

install().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
