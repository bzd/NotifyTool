# NotifyTool - Build & Setup Notes

## Summary

NotifyTool is a macOS command-line utility that sends notifications to the macOS Notification Center.

### What's Required to Make It Work

1. **Bundle structure** - A proper `.app` bundle in `~/Library/Application Support/NotifyTool.app`
2. **Code signing** - Signed with `codesign --force --deep --sign -` (ad-hoc signature)
3. **Run from bundle** - Must run from `~/Library/Application Support/NotifyTool.app/Contents/MacOS/notifytool`
4. **Focus mode** - Add NotifyTool to "Allowed Apps" in Focus Settings (if using Focus)

---

## Complete Build & Setup Instructions

### 1. Build the Release Binary

```bash
cd /path/to/NotifyTool
swift build -c release
```

### 2. Create the App Bundle (First Run)

Run the tool once from the build directory to create and sign the app bundle:

```bash
.build/arm64-apple-macosx/release/notifytool --title "Setup" --body "Creating bundle"
```

This will:
- Create `~/Library/Application Support/NotifyTool.app/`
- Copy the executable into the bundle
- Sign it with an ad-hoc signature
- Register it with Launch Services

> **Note:** The first run will fail with a permission error - that's expected.

### 3. Grant Notification Permission

1. Open **System Settings > Notifications**
2. Find **"NotifyTool"** in the list
3. Enable **"Allow Notifications"**
4. Set alert style to **"Banners"** or **"Alerts"**

### 4. Add to Focus Mode (if using Focus)

1. Open **System Settings > Focus**
2. Select your active Focus mode (e.g., "Do Not Disturb")
3. Under **"Allowed Apps"**, click **"Add"**
4. Add **"NotifyTool"**

### 5. Run Notifications

Always run from the bundle location:

```bash
~/Library/Application\ Support/NotifyTool.app/Contents/MacOS/notifytool --title "Title" --body "Message"
```

### 6. (Optional) Create Shell Alias

Add to `~/.zshrc`:

```bash
alias notifytool='~/Library/Application\ Support/NotifyTool.app/Contents/MacOS/notifytool'
```

Then:

```bash
source ~/.zshrc
notifytool --title "Test" --body "Hello!"
```

---

## Usage Examples

```bash
# Basic notification
notifytool --title "Backup Complete" --body "Your backup finished successfully."

# With subtitle
notifytool --title "Build" --body "Compilation finished" --subtitle "Project X"

# Without sound
notifytool --title "Silent" --body "No sound" --no-sound
```

---

## Rebuilding After Code Changes

After modifying the source code:

```bash
# Remove old bundle, rebuild, and recreate bundle
rm -rf ~/Library/Application\ Support/NotifyTool.app
swift build -c release
.build/arm64-apple-macosx/release/notifytool --title "x" --body "x" || true
```

Then run from the bundle as usual.

---

## Notes

- Ensure you run this in a GUI user session (not pure SSH) so the permission prompt and notifications appear.
- The notifications work with the macOS Notification Center! 🔔

