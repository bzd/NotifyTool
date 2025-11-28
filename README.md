# NotifyTool

A macOS command-line utility that sends notifications to the native Notification Center.

![macOS](https://img.shields.io/badge/macOS-11.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.7%2B-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- 🔔 Native macOS Notification Center integration
- 📝 Support for title, body, and subtitle
- 🔊 Optional sound control
- 🐍 Python wrapper for easy integration
- ⚡ Time-sensitive notification support (macOS 12+)
- 🔐 Ad-hoc code signing (no Apple Developer account required)

## Requirements

- macOS 11.0 (Big Sur) or later
- Swift 5.7 or later
- Xcode Command Line Tools

## Installation

### 1. Build the Release Binary

```bash
git clone https://github.com/bzd/NotifyTool.git
cd NotifyTool
swift build -c release
```

### 2. Create the App Bundle

Run the tool once to create and sign the app bundle:

```bash
.build/arm64-apple-macosx/release/notifytool --title "Setup" --body "Creating bundle"
```

This automatically:
- Creates `~/Library/Application Support/NotifyTool.app/`
- Copies the executable into the bundle
- Signs it with an ad-hoc signature
- Registers it with Launch Services

> **Note:** The first run will show a permission error - that's expected.

### 3. Grant Notification Permission

1. Open **System Settings > Notifications**
2. Find **"NotifyTool"** in the list
3. Enable **"Allow Notifications"**
4. Set alert style to **"Banners"** or **"Alerts"**

### 4. Add to Focus Mode (if using Focus)

If you use Focus/Do Not Disturb mode:

1. Open **System Settings > Focus**
2. Select your active Focus mode
3. Under **"Allowed Apps"**, click **"Add"**
4. Add **"NotifyTool"**

### 5. (Optional) Create Shell Alias

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
alias notifytool='~/Library/Application\ Support/NotifyTool.app/Contents/MacOS/notifytool'
```

Then reload:

```bash
source ~/.zshrc
```

## Usage

### Command Line

```bash
# Basic notification
notifytool --title "Backup Complete" --body "Your backup finished successfully."

# With subtitle
notifytool --title "Build" --body "Compilation finished" --subtitle "Project X"

# Without sound
notifytool --title "Silent" --body "No sound" --no-sound

# Show help
notifytool --help
```

### Options

| Option | Description |
|--------|-------------|
| `--title <text>` | Notification title (required) |
| `--body <text>` | Notification body (required) |
| `--subtitle <text>` | Optional subtitle |
| `--no-sound` | Disable notification sound |
| `--help`, `-h` | Show usage information |

### Python Integration

```python
from notify_from_python import send_notification

# Basic usage
send_notification(
    title="Task Complete",
    body="Your task has finished successfully."
)

# With all options
send_notification(
    title="Build Status",
    body="Compilation finished",
    subtitle="Project X",
    sound=False
)
```

## Rebuilding After Code Changes

After modifying the source code:

```bash
rm -rf ~/Library/Application\ Support/NotifyTool.app
swift build -c release
.build/arm64-apple-macosx/release/notifytool --title "x" --body "x" || true
```

Then run from the bundle as usual.

## How It Works

NotifyTool uses the `UserNotifications` framework to send native macOS notifications. Since this framework requires a proper app bundle, NotifyTool:

1. Creates a `.app` bundle structure in `~/Library/Application Support/`
2. Signs the bundle with an ad-hoc signature
3. Registers with Launch Services
4. Uses Objective-C runtime swizzling to present itself as the bundle

This allows a command-line tool to send notifications that appear in the native Notification Center with full support for banners, alerts, sounds, and Focus mode.

## Project Structure

```
NotifyTool/
├── Package.swift           # Swift Package Manager manifest
├── Sources/
│   └── NotifyTool/
│       └── main.swift      # Main application code
├── Info.plist              # App bundle configuration
├── notify_from_python.py   # Python wrapper
├── docs/
│   └── DEVELOPMENT.md      # Development notes
├── LICENSE                 # MIT License
├── CHANGELOG.md            # Version history
└── README.md               # This file
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

