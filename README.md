Usage Instructions
Save the script as removeChromeAiMac.sh.

Make it executable:

bash
chmod +x removeChromeAiMac.sh
Run it from the Terminal:

bash
./removeChromeAiMac.sh
You will be asked for your administrator password (because it writes to /Library/Managed Preferences).

After the script finishes, launch Chrome and go to chrome://policy to confirm the new settings.

Important Notes
The script does not delete your bookmarks, passwords, history, or extensions.

It only removes AI model files that Chrome may have downloaded (folders like OptGuideOnDeviceModel, OnDeviceModel, and certain cache directories inside OptimizationGuide).

The policy changes are applied system‑wide, so they affect all users on this Mac (which matches the Windows version that wrote to HKLM).

If you ever want to revert, you can restore the backed‑up plist files from your Desktop folder (Chrome_AI_Backup).