import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:logger/logger.dart';
import 'package:mindfulnotifier/components/constants.dart';
import 'package:mindfulnotifier/components/logging.dart';

var logger = Logger(printer: SimpleLogPrinter('reminderview'));

const htmlData = """
<h3>About this app</h3>

<p>This app is a simple mindfulness-based timer which displays a random
notification reminder taken from a configurable list. The provided notifications
are some simple examples. You can add and remove from the notifications defaults 
as you like.</p>

<p>Features:
<ul>
<li>Configure either a periodic or random reminder interval.</li>
<li>Edit or add your own reminder messages.</li>
<li>Use either a default bell or provide your own (in development).</li>
<li>Separate controls for mute and vibrate.</li>
</ul>

<h4>Project Information and Source Code</h4>
<p>The source code is available at <a href="https://github.com/kmac5">https://github.com/kmac5</a>.
Please see this link for additional help, or to report any issues.
<p>The default bell is taken from user 'steaq' at 
<a href="https://freesound.org/s/346328/">https://freesound.org/s/346328/</a>
and is licensed under the 'Creative Commons 0 License'.
See the link for more information.

<h4>Privacy Policy</h4>
<p>This application completely respects your privacy. It collects no data, other
than to store any customized reminders on your local device.
The app doesn't have access to the Internet, and it doesn't know or collect 
anything about you, or about your reminders.
</p>

<h4>Terms of service:</h4>
<p>This application is provided free of charge, with no warranty whatsoever.
</p>
""";

class AppAboutListTile extends AboutListTile {
  AppAboutListTile()
      : super(
            icon: Icon(Icons.info),
            applicationVersion: appVersion,
            applicationLegalese: '© 2021',
            aboutBoxChildren: [
              Html(data: htmlData),
            ]);
}
