# 1.0.12
- Issue 18 - fix periodic scheduling > 1 hr
- Issue 17 - add setting to hide next reminder info

# 1.0.11
- External storage changes (required by Google):
  - Remove android:requestLegacyExternalStorage="true" to conform to Android 11
  - Remove android.permission.READ_EXTERNAL_STORAGE, android.permission.WRITE_EXTERNAL_STORAGE permissions
- Backup/Restore changes (driven by the above):
  - Backup/Restore now use the application-specific external directory
    - Also given option to share the backup file using Android share facility
      - Share to local file system or cloud service, etc
      - This should be done to ensure the backup is preserved if you ever uninstall the app

# 1.0.10
- More fixes for move to data store in alarm/scheduler isolate
- Issue #9: fix dark color scheme dialogs
- Issue #6: fixes for backup/restore handling

# 1.0.9
- Update internal libraries
- Move all datastore writes into the alarm/scheduler isolate
  - Should fix issues with initial consistency of data

# 1.0.8
- Fix Issue #7 - fix bug in quiet hours end

# 1.0.7
- Remove quiet hours end callback

# 1.0.6
- Fixes after testing on Android 10 / LineageOS (Issue #2)
  - purely alarm driven
  - tweaking notifications which happen after main UI is killed

# 1.0.5
- cleanup/document permissions

# 1.0.4
- config changes required for publishing to fdroid

# 1.0.1
- minor code cleanup
- publishing to fdroid

# 1.0.0
- initial feature complete
- published to Google Play Store

# 0.0.1
- initial code
