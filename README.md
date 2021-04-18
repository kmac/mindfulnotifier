# mindfulnotifier

A mindfulness bell with configurable text notifications, schedules, and sound.

## About this app

This app is a simple mindfulness-based timer which displays a notification/reminder at user-defined intervals. It is another take on a
'Mindfulness Bell', with the addition of accompanying text.  The reminders are taken from a configurable list, and are chosen at random at a
selected interval. The reminder interval can either be periodic (in intervals down to a 15 minute granularity) or random (between a selected
range of minutes).

Some default reminders are provided as examples. You can add, edit, or remove these default reminders as you like.

There are 5 bells included, and you can also configure a custom bell from your phone's local storage.

This app works very well in conjunction with a smartwatch. In this mode you can also mute the bell to have silent mindfulness prompts
throughout your day.

The app is built using [Flutter](https://flutter.dev/).  It currently only runs on Android.


### Features:

- Configure either a periodic or random reminder interval.
    - e.g. hourly, or every 15 minutes, or randomly between 30 minutes and an hour
    - periodic intervals are aligned from the top of the hour
- Edit or add your own reminder messages.
    - Choose from a set of default bells, or provide your own.
- Separate controls for 'mute' and 'vibrate'.
- Define a time range for daily quiet hours.

### Permissions

This app uses the following permissions:

- `ACCESS_NETWORK_STATE`: Required by the library used to launch the github source code site
- `RECEIVE_BOOT_COMPLETED`: Required by the underlying alarm service to restart after reboot
- `WAKE_LOCK`: Required by the underlying alarm service to wake up at the scheduled time
- `USE_FULL_SCREEN_INTENT`: Required to show app in foreground from the reminder notification
- `VIBRATE`: Required to vibrate during notifications


### Notes on Application Settings in Android

#### Battery Optimization

Some phones will kill apps when running in the background after a relatively short period of time.  Unfortunately, if your phone is killing
the app then you will stop getting notifications.  If this is happening, you must disable any 'battery optimization' settings for this app.
This varies from phone-to-phone - generally you must go into the settings for the app on your phone and turn off any battery optimization.
See https://dontkillmyapp.com/ for your phone type and android version for more information.


### Bells

- Bell 1: is from user 'steaq' via [https://freesound.org/s/346328](https://freesound.org/s/346328/) and is licensed under the [Creative Commons 0 License][CC0].

- Bell 2: is from user 'itsallhappening' via [https://freesound.org/people/itsallhappening/sounds/48795](https://freesound.org/s/48795/) and is licensed under the [Creative Commons Sampling+ License][CCS]

- Bell 3: is from user 'suburban grilla' via [https://freesound.org/people/suburban%20grilla/sounds/2166](https://freesound.org/s/2166/) and is licensed under the [Creative Commons Sampling+ License][CCS]

- Bell 4: is from user 'kerri' via [https://freesound.org/people/kerri/sounds/27421/](https://freesound.org/people/kerri/sounds/27421/) and is licensed under the [Creative Commons Attribution License][CCA]

- Bell 5: is from user 'dobroide' via [https://freesound.org/people/dobroide/sounds/436976/](https://freesound.org/people/dobroide/sounds/436976/) and is licensed under the [Creative Commons Attribution License][CCA]

[CC0]: http://creativecommons.org/publicdomain/zero/1.0/   "Creative Commons 0 License"
[CCS]: http://creativecommons.org/licenses/sampling+/1.0/  "Creative Commons Sampling+ License"
[CCA]: https://creativecommons.org/licenses/by/3.0/        "Creative Commons Attribution License"


### Backup / Restore

This app provides basic backup and restore functionality. All of the preferences are exported to a file, which can then be restored on this
device, or another device. Note that if you ever uninstall the app, you will lose all of your customizations, including any
added/changed/removed reminders, so you should take a backup before uninstalling.

#### Backup:

The app saves a file called `Mindful Notifier-backup-<date>.json` in the app's external storage directory, which is located in your devices
internal storage in the folder `<Internal Storage>/Android/data/com.kmac5dev.mindfulnotifier/files`.  It also offers you a chance to 'share'
the file via the standard Android share menu (i.e. copy it to another location on your device, to Google Drive, to Dropbox, etc).

The 'share' step is important if:
- You uninstall the app. The app's storage directory is automatically removed when you uninstall the app.  You want to share the settings
- between devices.

You can also use a file browser to access the `<Internal Storage>/Android/data/com.kmac5dev.mindfulnotifier/files` location.

Note: the backup file is a 'json' text file. It is possible to edit the contents, but if you mess it up that's on you ;-).

#### Restore:

The restore operation allows you to choose the backup file using the system's file chooser. The app's settings will be restored from this
file. You should then restart the app, and re-enable the reminder service.


## License

This project is licensed under the terms of the GNU General Public License v3.0.

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.kmac5dev.mindfulnotifier"><img alt="Get it on Google Play" src="https://play.google.com/intl/en_us/badges/images/apps/en-play-badge-border.png" height="75px"/></a>
  <a href="https://f-droid.org/en/packages/com.kmac5dev.mindfulnotifier"><img alt="Get it on F-Droid" src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png" height="80"/></a>
</p>
