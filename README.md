# Chrome AI Cleaner (macOS)

Shell script (`removeChromeAi.sh`) to disable built‑in AI features in Google Chrome on macOS (Gemini, AI Mode, local on‑device AI model).

## What the script does

1. **Closes Chrome** if it is running.
2. **Backs up existing Chrome managed preferences** (if any) to `~/Desktop/Chrome_AI_Backup` before changing anything.
3. **Sets Chrome enterprise policies** (system‑wide) that permanently disable AI features:
   - `GenAILocalFoundationalModelSettings = 1` – disables the local (on‑device) AI model
   - `GeminiSettings = 1` – disables Gemini integration
   - `AIModeSettings = 1` – disables AI Mode in search
4. **Finds and deletes any existing locally downloaded AI model files** (e.g. `weights.bin` inside `OptGuideOnDeviceModel`, `OnDeviceModel`, `OptimizationGuide` folders) within Chrome profiles, to free up disk space immediately.
5. **Does not touch** bookmarks, passwords, history, or extensions.
6. At the end, it displays the current state of the set policies for verification.

## Important note about disk space

After deletion, Chrome **may re‑download** the AI model files in the background (via the internal "Component Updater" mechanism) the next time it starts. This is normal and **not a problem** – even though the file reappears on disk (usually a few hundred MB), the AI features remain inactive because of the policies set in step 3. You can re‑run the script at any time to delete that file again if it bothers you.

## How to use

1. Download `removeChromeAi.sh`.
2. Open **Terminal** and make the script executable:  
   `chmod +x /path/to/removeChromeAi.sh`
3. Run the script with **sudo** (it needs administrator privileges to write the system‑wide policy plist):  
   `sudo /path/to/removeChromeAi.sh`
4. Follow the on‑screen instructions, press any key when prompted.
5. After completion, open Chrome and go to `chrome://policy`, then click **Reload policies** to apply the changes immediately.
6. Verify that `GenAILocalFoundationalModelSettings` is set to `1`.

## Requirements

- macOS with Google Chrome installed
- Administrator rights (the script will prompt for your password when run with `sudo`)

## Safety

The script only writes to the system‑wide Chrome managed preferences plist (`/Library/Managed Preferences/com.google.Chrome.plist`) and deletes only AI model files inside recognised AI folders within the Chrome profile (`~/Library/Application Support/Google/Chrome/`). It does not touch other parts of the system. A backup of the original plist is automatically saved before any changes, so changes can be manually reverted by copying the backup `.plist` back to `/Library/Managed Preferences/` if needed.
