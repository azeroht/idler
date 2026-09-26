# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.2.2] - 2026-09-26

### 🐛 Bug fixes

- 🔒️ **state**: read and write the state file through a hardened script (44c1519)

## [0.2.1] - 2026-09-26

### 👷 Build and CI

- ⬆️ **deps**: Bump actions/checkout from 4 to 7 (4b2c5b3)

## [0.2.0] - 2026-09-26

### ✨ Features

- ✨ **action**: hold the key down for a configurable time on each pulse (d3e0e60)
- ✨ **timer**: wait a configurable delay before the first pulse (87fcd30)

### 🐛 Bug fixes

- 🐛 **panel**: let the settings panel receive keyboard input (4a37191)
- 🐛 **panel**: apply a typed number without waiting for enter (563105a)

### 💄 UI and UX

- 🚸 **panel**: step number fields with the mouse wheel, ten at a time with shift (5c63aa8)
- 💄 **panel**: show a hold example in the field label (f7bba4e)

### 📝 Documentation

- 📝 **readme**: document the hold example and the new screenshots (22bdb1c)

### 🔧 Chores

- 🍱 **docs**: refresh the screenshots with the new settings (afff638)
- 🔧 **github**: add a codeowners file for automatic review requests (a798380)
- 🔧 **github**: let dependabot keep the ci actions up to date (369f438)

## [0.1.1] - 2026-09-25

### 📝 Documentation

- 📝 add uninstall steps and a marketplace preview image (c8fafee)

## [0.1.0] - 2026-09-25

### ✨ Features

- ✨ add the idler bar widget, settings panel and pulse script (a502e58)

### 📝 Documentation

- 📝 write the readme and the changelog (c954d6e)

### ✅ Tests

- ✅ cover the model, the package and the pulse script (aa09417)

### 👷 Build and CI

- 👷 lint and test on the self-hosted runner (d1ba1f4)
- 👷 run on GitHub-hosted runners with read-only permissions (f10c166)
- 💚 pass the test files to node --test explicitly for node 22 (18d193b)
- 👷 harden the workflow for the public repository (d5ba25d)

### 🔧 Chores

- 🎉 begin project (0c16f08)
- 🍱 **docs**: add the banner and screenshots (9e2e9d8)
