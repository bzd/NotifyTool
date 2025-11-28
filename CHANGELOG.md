# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-28

### Added
- Initial release of NotifyTool
- Send notifications to macOS Notification Center via command line
- Support for notification title, body, and subtitle
- Optional sound with `--no-sound` flag
- Automatic app bundle creation in `~/Library/Application Support/NotifyTool.app`
- Ad-hoc code signing for notification permissions
- Launch Services registration
- Foreground notification support via `UNUserNotificationCenterDelegate`
- Time-sensitive notification support (macOS 12+)
- Python wrapper script for integration with Python projects
- Support for macOS 11.0 (Big Sur) and later

### Technical Details
- Uses `UserNotifications` framework for native Notification Center integration
- Creates and manages `.app` bundle structure automatically
- Swizzles `Bundle.main` to work around command-line tool limitations
- Supports both direct execution and shell alias usage

[1.0.0]: https://github.com/YOUR_USERNAME/NotifyTool/releases/tag/v1.0.0

