#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, "..");
const packageJsonPath = path.join(rootDir, "package.json");
const xcodeProjectPath = path.join(rootDir, "iFans.xcodeproj", "project.pbxproj");
const validLevels = new Set(["patch", "minor", "major"]);

function printUsage() {
  console.log("Usage: npm run version:bump -- [patch|minor|major]");
  console.log("Default: patch");
}

function bumpSemver(version, level) {
  const match = version.match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!match) {
    throw new Error(`Unsupported version format: ${version}`);
  }

  let [major, minor, patch] = match.slice(1).map(Number);

  if (level === "major") {
    major += 1;
    minor = 0;
    patch = 0;
  } else if (level === "minor") {
    minor += 1;
    patch = 0;
  } else {
    patch += 1;
  }

  return `${major}.${minor}.${patch}`;
}

const args = process.argv.slice(2);
if (args.includes("--help") || args.includes("-h")) {
  printUsage();
  process.exit(0);
}

const level = args[0] ?? "patch";
if (!validLevels.has(level)) {
  console.error(`Unknown bump level: ${level}`);
  printUsage();
  process.exit(1);
}

const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
const nextVersion = bumpSemver(packageJson.version, level);

packageJson.version = nextVersion;
fs.writeFileSync(packageJsonPath, `${JSON.stringify(packageJson, null, 2)}\n`);

const projectFile = fs.readFileSync(xcodeProjectPath, "utf8");
const updatedProjectFile = projectFile.replace(
  /MARKETING_VERSION = [^;]+;/g,
  `MARKETING_VERSION = ${nextVersion};`
);

if (updatedProjectFile === projectFile) {
  throw new Error("MARKETING_VERSION not found in iFans.xcodeproj/project.pbxproj");
}

fs.writeFileSync(xcodeProjectPath, updatedProjectFile);

console.log(`Updated package.json and Xcode MARKETING_VERSION to ${nextVersion}`);
