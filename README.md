----------

NOTE - This is a hobby project created primarily for my personal needs. 

----------


# Chrome AI Cleaner (macOS)

Shell script (`removeChromeAiMAC.sh`) that disables the built-in AI features in Google Chrome on macOS (Gemini, AI Mode, local on-device AI model) and deletes the already downloaded local model files.

## What the script does

1. **Requests administrator rights** (re-launches itself with `sudo` if needed) and works out the real logged-in user, so backups and files are never created as root-owned in your home folder.
2. **Closes Chrome** if it is running (quit gracefully first, then forced).
3. **Backs up the existing Chrome managed-policy plist** (only if it exists) to `~/Desktop/Chrome_AI_Backup`. An existing backup is **never overwritten**, so re-running the script cannot replace your original settings with the modified ones.
4. **Sets Chrome policies** system-wide in `/Library/Managed Preferences/com.google.Chrome.plist`:
   - `GenAILocalFoundationalModelSettings = 1` - disables the local (on-device) AI model
   - `GeminiSettings = 1` - disables Gemini integration
   - `AIModeSettings = 1` - disables AI Mode in search

   The file gets `root:wheel` / `644` and the preferences cache (`cfprefsd`) is restarted so the values apply without a reboot.
5. **Finds and deletes local AI model folders** anywhere inside `~/Library/Application Support/Google/Chrome`:
   - `OptGuideOnDeviceModel`
   - `OnDeviceModel`
   - any leftover `weights.bin` located inside one of those folders
6. **Verifies** the policy values by reading them back from the plist.

Bookmarks, passwords, history and extensions are not touched.

## Notes

- **Disk space:** Chrome may re-download the model in the background the next time it starts. With the policies set the AI features stay inactive, so this is harmless; re-run the script to remove the file again.
- **"Managed by your organization":** because the policies are set as managed preferences, Chrome will show this notice in the menu and in `chrome://settings`. This is expected.
- **MDM-managed Macs:** if the Mac is enrolled in MDM (work/school), the profile may overwrite or remove `/Library/Managed Preferences/` and policies may be reset.
- Only stable **Google Chrome** is handled (not Chrome Beta/Dev/Canary or Chromium).
- The policies apply to all users on the Mac.

## How to use

1. Download `removeChromeAiMAC.sh`.
2. Open **Terminal** and run it with `sudo` (no `chmod` needed):
   `sudo bash /path/to/removeChromeAiMAC.sh`
3. Enter your password and press a key when prompted.
4. Start Chrome, open `chrome://policy` and click **Reload policies**.
5. Verify that `GenAILocalFoundationalModelSettings`, `GeminiSettings` and `AIModeSettings` are all set to `1`.

## Reverting

Restore the original file and restart the preferences cache:

```
sudo cp ~/Desktop/Chrome_AI_Backup/Chrome_System_Managed.plist "/Library/Managed Preferences/com.google.Chrome.plist"
sudo killall cfprefsd
```

If there was no policy file before (no backup was created), remove only the keys the script added:

```
for k in GenAILocalFoundationalModelSettings GeminiSettings AIModeSettings; do
  sudo /usr/libexec/PlistBuddy -c "Delete :$k" "/Library/Managed Preferences/com.google.Chrome.plist"
done
sudo killall cfprefsd
```

## Requirements

- macOS with Google Chrome installed
- Administrator rights (password prompt via `sudo`)

## Safety

The script only writes to `/Library/Managed Preferences/com.google.Chrome.plist` and only deletes folders named `OptGuideOnDeviceModel` / `OnDeviceModel` (and `weights.bin` inside them) within Chrome's profile directory. Nothing else on the system is modified.
