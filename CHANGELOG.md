# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### ✨ Added

- Bar widget with a mouse icon: left click starts or stops, right click opens the settings.
- Settings panel: F15, F13, Shift or a 1 px mouse nudge, any other keysym, interval in ms or s.
- State kept in `~/.local/state/azeroht-idler.json`, shared by the bars of every monitor.
- IPC target `azeroht.idler`: `toggle`, `start`, `stop`, `open`, `close`, `status`.
- Unit tests for the model, the package and the pulse script, run by CI.
