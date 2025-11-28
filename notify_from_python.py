# ==========================================
# file: notify_from_python.py
# ==========================================
"""
Simple Python helper that calls the notifytool CLI.
"""

import os
import subprocess
from typing import Optional

# Default path to the NotifyTool binary (in the user's Application Support)
DEFAULT_BINARY_PATH = os.path.join(
    os.path.expanduser("~"),
    "Library/Application Support/NotifyTool.app/Contents/MacOS/notifytool"
)


def send_notification(
    title: str,
    body: str,
    subtitle: Optional[str] = None,
    sound: bool = True,
    binary_path: str = DEFAULT_BINARY_PATH,
) -> None:
    cmd = [binary_path, "--title", title, "--body", body]
    if subtitle:
        cmd += ["--subtitle", subtitle]
    if not sound:
        cmd.append("--no-sound")

    # Raises CalledProcessError if the tool fails.
    subprocess.run(cmd, check=True)


if __name__ == "__main__":
    send_notification(
        title="Backup Complete",
        body="Your backup finished successfully.",
        subtitle="Job #42",
        sound=False
    )
