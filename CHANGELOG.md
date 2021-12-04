# 1.0.23
- Back button now minimizes the app instead of closing it.
  This is like the home button is pressed instead of back.

# 1.0.22
- Fix issue where new notification is generated instead
  of showing existing notification (after app is restarted).

# 1.0.21
- Fix UI re-init issue with recreating the initial notification
  when app is revisited after being killed (either on restart
  or when user uses the back button to exit instead of the
  home button)
    - If user presses the back button the app is killed (but
      the alarm service is still running, and notifications
      still occur).
    - This fixes the notification being re-raised/changed
      when the app is again started by the user

# 1.0.20
- Issue #35: fix service disabled on app open after close
    - Migrate from SharedPreferences to Hive for internal data
    - add nextAlarm field in db to track state for restart
- Update to android targetSdkVersion 30 (required for Play Store)
- Update internal libraries and dependencies
- Remove some test reminders that were mistakenly included in the
  last release. This affects new installs only - if you recently
  installed please manually delete any reminders that don't make
  sense to you!

# 1.0.19
- Issue #31/#36: Revisit sound modes for different channels
- Summary:
    - App mute is enabled: always mute
    - For notification channel: honour the phone silent/vibrate-only setting
    - For media and alarm channels, allow sound unless DND is enabled

# 1.0.18
- Issue #32: Fix crash when reminder created with empty string

# 1.0.17
- Issue #32: Fix crash on earlier android versions caused by flutter_native_timezone

# 1.0.16
- 'Bell' configuration menu is now called 'Sound'
- Add ability to select media channel for notification sound (Issue 31):
    - notification (default, as in previous versions)
    - media
    - alarm

# 1.0.15
- Issue 26: allow to select from existing tags on add/edit
    - Can also add new tag via manual text
- Issue 25: Increase maximum characters per reminder
    - Increased from 256 to 4096 characters
    - Reminders are truncated in notifications. Will be
      shown in full on main screen via scrolling
- Issue 24: slight change to randomize function

# 1.0.14
- Rework reminder list UI and features for Issue #15 (tagging) and Issue #20
    - Ability to enable/disable individual reminders
    - Supports simple 'tag' field to categorize groups of reminders
    - Reminder list can be filtered by tag
    - Reminder list is always automatically sorted:
        - Alphabetical
        - Disabled reminders are moved to end of list
- Backup/Restore changed to Reminder Export/Import:
    - No longer does full backup/restore of all settings
        - NOTE: Existing backup files will still work - however, only the reminders will be restored.
    - Core function is changed to provide only reminder export/import
    - Reminder list export/import via JSON file format.
        - See: Issue #20 (simpler file format for reminder sharing)
    - New 'Merge' when importing reminder list:
        - 'Merge' will preserve existing reminders in list; only new reminders are added
        - 'Replace' completely replaces existing reminders list
- Fix issue #11, issue when updating schedule min/max values

# 1.0.13
- Issue #21 - ensure silent notifications in Do Not Disturb
- Issue #16 - add sharing option (long press on main screen to share)

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
