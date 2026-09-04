#!/bin/bash

# ============================================================
# GOOGLE CHROME - AI CLEANER (macOS) - by Sveto (ported)
# ============================================================
# This script:
#   1. Closes Chrome
#   2. Backs up existing Chrome policy plists
#   3. Disables local AI models / Gemini / AI Mode
#   4. Deletes downloaded local AI models
#
# Bookmarks, passwords, history, and extensions are untouched.
# ============================================================

set -e

# ------------------------------------------------------------
# Check for macOS
# ------------------------------------------------------------
if [[ "$(uname)" != "Darwin" ]]; then
    echo "This script is intended for macOS only."
    exit 1
fi

# ------------------------------------------------------------
# Admin privileges check & auto‑elevation
# ------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "Administrator privileges are required to set system policies."
    echo "Re‑running with sudo..."
    sudo "$0" "$@"
    exit $?
fi

# ------------------------------------------------------------
# Variables
# ------------------------------------------------------------
CHROME_USER_DATA="$HOME/Library/Application Support/Google/Chrome"
BACKUP_DIR="$HOME/Desktop/Chrome_AI_Backup"
SYSTEM_PLIST="/Library/Managed Preferences/com.google.Chrome.plist"
USER_PLIST="$HOME/Library/Preferences/com.google.Chrome.plist"

# ------------------------------------------------------------
# Create backup directory
# ------------------------------------------------------------
mkdir -p "$BACKUP_DIR"

echo "============================================================"
echo "          GOOGLE CHROME - AI CLEANER (macOS)"
echo "============================================================"
echo
echo "This script will:"
echo
echo "  [1] Close Chrome"
echo "  [2] Backup existing policy files"
echo "  [3] Disable Chrome AI features (system policy)"
echo "  [4] Remove downloaded local AI models"
echo
echo "Bookmarks, passwords, history and extensions are NOT touched."
echo
read -p "Press any key to continue..." -n1 -s
echo

# ------------------------------------------------------------
# 1. Close Chrome
# ------------------------------------------------------------
echo
echo "============================================================"
echo "[1/5] Closing Chrome"
echo "============================================================"
pkill -x "Google Chrome" 2>/dev/null || echo "Chrome was not running."
sleep 2
echo "[OK] Chrome closed."

# ------------------------------------------------------------
# 2. Backup policy plists
# ------------------------------------------------------------
echo
echo "============================================================"
echo "[2/5] Backing up policy files"
echo "============================================================"

if [[ -f "$SYSTEM_PLIST" ]]; then
    cp "$SYSTEM_PLIST" "$BACKUP_DIR/Chrome_System_Managed.plist"
    echo "[OK] System policy backed up."
else
    echo "[INFO] No existing system policy file found."
fi

if [[ -f "$USER_PLIST" ]]; then
    cp "$USER_PLIST" "$BACKUP_DIR/Chrome_User_Defaults.plist"
    echo "[OK] User defaults backed up."
else
    echo "[INFO] No existing user defaults file found."
fi

# ------------------------------------------------------------
# 3. Disable AI features via system policy
# ------------------------------------------------------------
echo
echo "============================================================"
echo "[3/5] Disabling Chrome AI features"
echo "============================================================"

# Create or modify the system‑wide managed preferences plist
/usr/libexec/PlistBuddy -c "Add :GenAILocalFoundationalModelSettings integer 1" "$SYSTEM_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :GenAILocalFoundationalModelSettings 1" "$SYSTEM_PLIST"

/usr/libexec/PlistBuddy -c "Add :GeminiSettings integer 1" "$SYSTEM_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :GeminiSettings 1" "$SYSTEM_PLIST"

/usr/libexec/PlistBuddy -c "Add :AIModeSettings integer 1" "$SYSTEM_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :AIModeSettings 1" "$SYSTEM_PLIST"

# Also set them in user defaults (as a fallback)
defaults write com.google.Chrome GenAILocalFoundationalModelSettings -int 1
defaults write com.google.Chrome GeminiSettings -int 1
defaults write com.google.Chrome AIModeSettings -int 1

echo "[OK] AI policies set:"
echo "     GenAILocalFoundationalModelSettings = 1"
echo "     GeminiSettings = 1"
echo "     AIModeSettings = 1"

# ------------------------------------------------------------
# 4. Delete local AI models
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

    # -----------------------------------------------------------------
    # OptGuideOnDeviceModel
    # -----------------------------------------------------------------
    echo "Searching for OptGuideOnDeviceModel..."
    find "$CHROME_USER_DATA" -type d -name "OptGuideOnDeviceModel" -print0 | while IFS= read -r -d '' dir; do
        echo "[FOUND] $dir"
        echo "[DELETE] Removing..."
        rm -rf "$dir" 2>/dev/null && echo "[OK] Removed." || echo "[WARNING] Could not remove."
        echo
    done

    # -----------------------------------------------------------------
    # OnDeviceModel
    # -----------------------------------------------------------------
    echo "Searching for OnDeviceModel..."
    find "$CHROME_USER_DATA" -type d -name "OnDeviceModel" -print0 | while IFS= read -r -d '' dir; do
        echo "[FOUND] $dir"
        echo "[DELETE] Removing..."
        rm -rf "$dir" 2>/dev/null && echo "[OK] Removed." || echo "[WARNING] Could not remove."
        echo
    done

    # -----------------------------------------------------------------
    # OptimizationGuide – delete only subdirectories containing "model" or "optimization"
    # -----------------------------------------------------------------
    echo "Searching for OptimizationGuide subdirectories..."
    find "$CHROME_USER_DATA" -type d -name "OptimizationGuide" -print0 | while IFS= read -r -d '' dir; do
        echo "[FOUND] $dir"
        # Remove subdirs that match *model* or *optimization* (case‑insensitive)
        find "$dir" -mindepth 1 -maxdepth 1 -type d -iname "*model*" -o -iname "*optimization*" -print0 | while IFS= read -r -d '' subdir; do
            echo "[DELETE] $subdir"
            rm -rf "$subdir" 2>/dev/null && echo "[OK] Removed." || echo "[WARNING] Could not remove."
        done
        echo
    done

    # -----------------------------------------------------------------
    # weights.bin – only if path contains AI model directories
    # -----------------------------------------------------------------
    echo "Searching for weights.bin AI model files..."
    find "$CHROME_USER_DATA" -type f -name "weights.bin" -print0 | while IFS= read -r -d '' file; do
        # Check if the file path contains one of the known AI folders
        if [[ "$file" =~ (OptGuideOnDeviceModel|OnDeviceModel|OptimizationGuide) ]]; then
            echo "[FOUND AI MODEL] $file"
            echo "[DELETE] Removing..."
            rm -f "$file" 2>/dev/null && echo "[OK] Removed." || echo "[WARNING] Could not remove."
            echo
        fi
    done
fi

# ------------------------------------------------------------
# 5. Verification
# ------------------------------------------------------------
echo
echo "============================================================"
echo "[5/5] Verification"
echo "============================================================"
echo
echo "Current system policy values:"
/usr/libexec/PlistBuddy -c "Print :GenAILocalFoundationalModelSettings" "$SYSTEM_PLIST" 2>/dev/null || echo "  GenAILocalFoundationalModelSettings: (not set)"
/usr/libexec/PlistBuddy -c "Print :GeminiSettings" "$SYSTEM_PLIST" 2>/dev/null || echo "  GeminiSettings: (not set)"
/usr/libexec/PlistBuddy -c "Print :AIModeSettings" "$SYSTEM_PLIST" 2>/dev/null || echo "  AIModeSettings: (not set)"

echo
echo "============================================================"
echo "                       DONE"
echo "============================================================"
echo
echo "Backup files are stored in:"
echo "$BACKUP_DIR"
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
echo "		PS. Install Linux   :P"
echo "============================================================"

exit 0