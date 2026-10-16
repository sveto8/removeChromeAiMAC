#!/bin/bash

# ============================================================
# GOOGLE CHROME - AI CLEANER (macOS) - by Sveto (ported)
# ============================================================
# This script:
#   1. Closes Chrome
#   2. Backs up the existing Chrome managed-policy plist
#   3. Disables local AI model / Gemini / AI Mode via system policy
#   4. Deletes downloaded local AI models
#   5. Verifies the result
#
# Bookmarks, passwords, history, and extensions are untouched.
# ============================================================

# ------------------------------------------------------------
# Check for macOS
# ------------------------------------------------------------
if [[ "$(uname)" != "Darwin" ]]; then
    echo "This script is intended for macOS only."
    exit 1
fi

# ------------------------------------------------------------
# Admin privileges check & auto-elevation
# (run through /bin/bash so the executable bit is not required)
# ------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "Administrator privileges are required to set system policies."
    echo "Re-running with sudo..."
    exec sudo /bin/bash "$0" "$@"
fi

# ------------------------------------------------------------
# Work out the REAL user. Under sudo, "$HOME" / "defaults" /
# "mkdir" may point at or create files owned by root.
# ------------------------------------------------------------
REAL_USER="${SUDO_USER:-$(stat -f '%Su' /dev/console)}"
REAL_HOME="$(dscl . -read "/Users/$REAL_USER" NFSHomeDirectory 2>/dev/null | sed 's/^NFSHomeDirectory: *//')"

if [[ -z "$REAL_USER" || "$REAL_USER" == "root" || ! -d "$REAL_HOME" ]]; then
    echo "[ERROR] Could not determine the logged-in user's home folder."
    echo "        Run this script with 'sudo' from your normal user account."
    exit 1
fi

# ------------------------------------------------------------
# Variables
# ------------------------------------------------------------
CHROME_USER_DATA="$REAL_HOME/Library/Application Support/Google/Chrome"
BACKUP_DIR="$REAL_HOME/Desktop/Chrome_AI_Backup"
POLICY_DIR="/Library/Managed Preferences"
SYSTEM_PLIST="$POLICY_DIR/com.google.Chrome.plist"
BACKUP_FILE="$BACKUP_DIR/Chrome_System_Managed.plist"
PB="/usr/libexec/PlistBuddy"
POLICIES=(GenAILocalFoundationalModelSettings GeminiSettings AIModeSettings)

echo "============================================================"
echo "          GOOGLE CHROME - AI CLEANER (macOS)"
echo "============================================================"
echo
echo "This script will:"
echo
echo "  [1] Close Chrome"
echo "  [2] Back up the existing policy file"
echo "  [3] Disable Chrome AI features (system policy)"
echo "  [4] Remove downloaded local AI models"
echo "  [5] Verify the result"
echo
echo "Bookmarks, passwords, history and extensions are NOT touched."
echo
read -p "Press any key to continue..." -n1 -s
echo

# ------------------------------------------------------------
# [1/5] Close Chrome
# ------------------------------------------------------------
echo
echo "============================================================"
echo "[1/5] Closing Chrome"
echo "============================================================"
if pgrep -x "Google Chrome" >/dev/null 2>&1; then
    sudo -u "$REAL_USER" osascript -e 'tell application "Google Chrome" to quit' >/dev/null 2>&1
    sleep 3
    pkill -x "Google Chrome" 2>/dev/null
    sleep 1
    echo "[OK] Chrome closed."
else
    echo "[INFO] Chrome was not running."
fi

# ------------------------------------------------------------
# [2/5] Backup policy plist
# An existing backup is NEVER overwritten, so re-running the
# script cannot replace your original settings with modified ones.
# ------------------------------------------------------------
echo
echo "============================================================"
echo "[2/5] Backing up policy file"
echo "============================================================"

mkdir -p "$BACKUP_DIR"

if [[ -f "$BACKUP_FILE" ]]; then
    echo "[INFO] Backup already exists, keeping the original."
elif [[ -f "$SYSTEM_PLIST" ]]; then
    cp "$SYSTEM_PLIST" "$BACKUP_FILE" && echo "[OK] System policy backed up."
else
    echo "[INFO] No existing system policy file found, nothing to back up."
fi
chown -R "$REAL_USER" "$BACKUP_DIR"

# ------------------------------------------------------------
# [3/5] Disable AI features via system (managed) policy
# Chrome on macOS only honours *managed* preferences, so
# "defaults write com.google.Chrome ..." would have no effect.
# ------------------------------------------------------------
echo
echo "============================================================"
echo "[3/5] Disabling Chrome AI features"
echo "============================================================"

mkdir -p "$POLICY_DIR"

for key in "${POLICIES[@]}"; do
    if "$PB" -c "Add :$key integer 1" "$SYSTEM_PLIST" >/dev/null 2>&1 \
    || "$PB" -c "Set :$key 1" "$SYSTEM_PLIST" >/dev/null 2>&1; then
        echo "[OK] $key = 1"
    else
        echo "[ERROR] Could not set $key"
    fi
done

# Correct ownership/permissions and drop the preferences cache
# so the new values are picked up without a reboot.
chown root:wheel "$SYSTEM_PLIST" 2>/dev/null
chmod 644 "$SYSTEM_PLIST" 2>/dev/null
killall cfprefsd 2>/dev/null

# ------------------------------------------------------------
# [4/5] Delete local AI models
# ------------------------------------------------------------
echo
echo "============================================================"
echo "[4/5] Searching for and deleting local AI models"
echo "============================================================"

if [[ ! -d "$CHROME_USER_DATA" ]]; then
    echo "[INFO] Chrome User Data folder not found."
else
    echo "Chrome User Data: $CHROME_USER_DATA"
    echo

    for name in OptGuideOnDeviceModel OnDeviceModel; do
        echo "Searching for $name..."
        # -prune: do not descend into a match we are about to delete
        while IFS= read -r -d '' dir; do
            echo "[FOUND]  $dir"
            if rm -rf "$dir" 2>/dev/null; then
                echo "[OK] Removed."
            else
                echo "[WARNING] Could not remove."
            fi
            echo
        done < <(find "$CHROME_USER_DATA" -type d -name "$name" -prune -print0 2>/dev/null)
    done

    # Safety net: weights.bin still sitting inside a recognised AI folder
    echo "Searching for leftover weights.bin..."
    while IFS= read -r -d '' file; do
        echo "[FOUND]  $file"
        if rm -f "$file" 2>/dev/null; then
            echo "[OK] Removed."
        else
            echo "[WARNING] Could not remove."
        fi
        echo
    done < <(find "$CHROME_USER_DATA" -type f -name "weights.bin" \
                \( -path '*/OptGuideOnDeviceModel/*' -o -path '*/OnDeviceModel/*' \) \
                -print0 2>/dev/null)
fi

# ------------------------------------------------------------
# [5/5] Verification
# ------------------------------------------------------------
echo
echo "============================================================"
echo "[5/5] Verification"
echo "============================================================"
echo
echo "Current system policy values ($SYSTEM_PLIST):"
for key in "${POLICIES[@]}"; do
    if val="$("$PB" -c "Print :$key" "$SYSTEM_PLIST" 2>/dev/null)"; then
        echo "  $key = $val"
    else
        echo "  $key: (not set)"
    fi
done

echo
echo "============================================================"
echo "                       DONE"
echo "============================================================"
echo
echo "Backup file is stored in:"
echo "  $BACKUP_DIR"
echo
echo "Now start Chrome and open:"
echo "  chrome://policy"
echo
echo "Click 'Reload policies' and verify that the following keys are present and set to 1:"
echo "  GenAILocalFoundationalModelSettings"
echo "  GeminiSettings"
echo "  AIModeSettings"
echo
echo "============================================================"
echo "   PS. Install Linux   :P"
echo "============================================================"

exit 0
