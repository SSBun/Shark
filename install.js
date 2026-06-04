#!/usr/bin/env node
const { execFile } = require("child_process");
const path = require("path");
const fs = require("fs");

const dmgPath = path.join(__dirname, "SharkSpace.dmg");

if (!fs.existsSync(dmgPath)) {
  console.error("SharkSpace.dmg not found in package.");
  process.exit(1);
}

console.log("Opening SharkSpace DMG...");
console.log("Drag SharkSpace to Applications to install.\n");

execFile("open", [dmgPath], (err) => {
  if (err) {
    console.error("Failed to open DMG:", err.message);
    process.exit(1);
  }

  console.log(
    "\x1b[33m%s\x1b[0m",
    "⚠  If macOS blocks SharkSpace from opening, run:\n"
  );
  console.log("    sudo spctl --master-disable\n");
  console.log(
    "Then go to System Settings → Privacy & Security → select 'Anywhere'.\n"
  );
});
