import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import 'package:mindfulnotifier/components/constants.dart';
import 'package:mindfulnotifier/components/logging.dart';

var logger = Logger(printer: SimpleLogPrinter('about'));

const markdownData = """
## About this app

This app is a simple mindfulness-based timer which displays a 
notification/reminder at user-defined intervals. Reminders are, taken 
from a configurable list. Reminders can be configured
for either periodic (down to 15 minute intervals) or random intervals.
Some default notifications are provided as simple examples. 
You can add and remove from the notifications defaults as you like.
There are 5 bells included, and you can also configure a custom bell
from your phone's local storage.

The app is built using [Flutter](https://flutter.dev/).

It currently only runs on Android.


### Features:

* Configure either a periodic or random reminder interval.
    - e.g. hourly, or every 15 minutes, or randomly between 30 minues and an hour
* Edit or add your own reminder messages.
* Choose from a set of default bells, or provide your own.
* Separate controls for mute and vibrate.
* Define a range of time for quiet hours.


## Project Information and Source Code

The source code is available on github at [mindfulnotifier](https://github.com/kmac5/mindfulnotifier)
Please see this link for additional help, or to report any issues.


### Bells

* Bell 1: is from user 'steaq' via [https://freesound.org/s/346328](https://freesound.org/s/346328/)
and is licensed under the [Creative Commons 0 License][CC0].

* Bell 2: is from user 'itsallhappening' via [https://freesound.org/people/itsallhappening/sounds/48795](https://freesound.org/s/48795/)
and is licensed under the [Creative Commons Sampling+ License][CCS]

* Bell 3: is from user 'suburban grilla' via [https://freesound.org/people/suburban%20grilla/sounds/2166](https://freesound.org/s/2166/)
and is licensed under the [Creative Commons Sampling+ License][CCS]

* Bell 4: is from user 'kerri' via [https://freesound.org/people/kerri/sounds/27421/](https://freesound.org/people/kerri/sounds/27421/)
and is licensed under the [Creative Commons Attribution License][CCA]

* Bell 5: is from user 'dobroide' via [https://freesound.org/people/dobroide/sounds/436976/](https://freesound.org/people/dobroide/sounds/436976/)
and is licensed under the [Creative Commons Attribution License][CCA]

[CC0]: http://creativecommons.org/publicdomain/zero/1.0/   "Creative Commons 0 License"
[CCS]: http://creativecommons.org/licenses/sampling+/1.0/  "Creative Commons Sampling+ License"
[CCA]: https://creativecommons.org/licenses/by/3.0/        "Creative Commons Attribution License"


## License

This project is licensed under the terms of the GNU General Public License v3.0.
""";

Future<void> launchInBrowser(String url) async {
  if (await canLaunch(url)) {
    await launch(
      url,
      forceSafariVC: false,
      forceWebView: false,
      headers: <String, String>{'my_header_key': 'my_header_value'},
    );
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
  AppAboutListTile()
      : super(icon: Icon(Icons.info), applicationVersion: appVersion,
            // applicationLegalese: '© 2021',
            aboutBoxChildren: [
              Center(
                child: OutlineButton(
                  child: Text("Visit project on github"),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    launchInBrowser('https://github.com/kmac5/mindfulnotifier');
                  },
                ),
              ),
              Divider(),
              Container(
                  child: MarkdownBody(
                      selectable: true,
                      shrinkWrap: true,
                      onTapLink: (text, href, title) => handleMarkdownOnTap,
                      data: markdownData)),
            ]);
}
