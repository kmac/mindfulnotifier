# 1.0.11
- Remove unneeded android.permission.READ_EXTERNAL_STORAGE, android.permission.WRITE_EXTERNAL_STORAGE permissions
- Remove unneeded android:requestLegacyExternalStorage="true" to conform to Android 11

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
