import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mindfulnotifier/components/constants.dart';
import 'package:mindfulnotifier/components/logging.dart';

var logger = createLogger('about');

const markdownData = """
## About this app

This app is a simple mindfulness-based timer which displays a
notification/reminder at user-defined intervals. It is another take on a
'Mindfulness Bell', with some accompanying text.  Reminders are taken from a
configurable list, and can be configured either for periodic or random
intervals.

Some default reminders are provided as examples. You can add, edit, or remove
these default reminders as you like. Reminders can be enabled/disabled and can
also be given a tag for easier grouping and browsing.

There are 5 bells included, and you can also configure a custom bell from your
phone's local storage.

This app works very well in conjunction with a smartwatch. In this mode you can
also mute the bell to have silent mindfulness prompts throughout your day.

The app is built using [Flutter](https://flutter.dev/).


### Features:

Main Features:

- Configure either a periodic or random reminder interval.
    - e.g. hourly, or every 15 minutes, or randomly between 30 minutes and an hour
    - periodic intervals are aligned from the top of the hour
- Edit or add your own reminder messages.
    - Choose from a set of default bells, or provide your own.
- Separate controls for 'mute' and 'vibrate'.
- Define a time range for daily quiet hours.


## Project Information and Source Code

The source code is available on github at https://github.com/kmac/mindfulnotifier
Please see this link for additional help, or to report any issues.

### Notes on Application Settings in Android

#### Battery Optimization

Some phones will kill apps when running in the background after a relatively
short period of time.  Unfortunately, if your phone is killing the app then you
will stop getting notifications.  If this is happening, you must disable any
'battery optimization' settings for this app. This varies from phone-to-phone -
generally you must go into the settings for the app on your phone and turn off
any battery optimization. See https://dontkillmyapp.com/ for your phone type
and android version for more information.


### Bells

The following bells are included:

- Bell 1: is from user 'steaq' via [https://freesound.org/people/steaq/sounds/346328/](https://freesound.org/people/steaq/sounds/346328/)
and is licensed under the [Creative Commons 0 License][CC0].
- Bell 2: is from user 'itsallhappening' via [https://freesound.org/people/itsallhappening/sounds/48795](https://freesound.org/s/48795/)
and is licensed under the [Creative Commons Sampling+ License][CCS]
- Bell 3: is from user 'suburban grilla' via [https://freesound.org/people/suburban%20grilla/sounds/2166](https://freesound.org/s/2166/)
and is licensed under the [Creative Commons Sampling+ License][CCS]
- Bell 4: is from user 'kerri' via [https://freesound.org/people/kerri/sounds/27421/](https://freesound.org/people/kerri/sounds/27421/)
and is licensed under the [Creative Commons Attribution License][CCA]
- Bell 5: is from user 'dobroide' via [https://freesound.org/people/dobroide/sounds/436976/](https://freesound.org/people/dobroide/sounds/436976/)
and is licensed under the [Creative Commons Attribution License][CCA]

[CC0]: http://creativecommons.org/publicdomain/zero/1.0/   "Creative Commons 0 License"
[CCS]: http://creativecommons.org/licenses/sampling+/1.0/  "Creative Commons Sampling+ License"
[CCA]: https://creativecommons.org/licenses/by/3.0/        "Creative Commons Attribution License"


## License

This project is licensed under the terms of the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.en.html).
""";

Future<void> launchInBrowser(String url) async {
  Uri uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  } else {
    throw 'Could not launch $url';
  }
}

handleMarkdownOnTap(String text, String href, String title) async {
  if (href != null) {
    logger.i("Launching text=$text, href=$href, title=$title");
    await launchInBrowser(href);
  }
}

class AppAboutListTile extends AboutListTile {
  AppAboutListTile(BuildContext context)
      : super(
            icon: Icon(Icons.info),
            applicationVersion: appVersion,
            applicationLegalese:
                'This is open-source free/libre software, licensed under GPL v3.0',
            aboutBoxChildren: [
              Center(
                child: OutlinedButton(
                  child: Text("Visit project on github"),
                  // visualDensity: VisualDensity.compact,
                  onPressed: () {
                    launchInBrowser('https://github.com/kmac/mindfulnotifier');
                  },
                ),
              ),
              Divider(),
              Container(
                  child: MarkdownBody(
                selectable: true,
                shrinkWrap: true,
                onTapLink: (text, href, title) => handleMarkdownOnTap,
                data: markdownData,
                // styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                //     .copyWith(
                //         textAlign: WrapAlignment.center,
                //         blockquoteAlign: WrapAlignment.end,
                //         unorderedListAlign: WrapAlignment.center,
                //         listIndent: 2),
              )),
            ]);
}
