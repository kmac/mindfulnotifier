import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:logger/logger.dart';
import 'package:mindfulnotifier/components/constants.dart';
import 'package:mindfulnotifier/components/logging.dart';

var logger = Logger(printer: SimpleLogPrinter('about'));

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
<p>The source code is available at <a href="https://github.com/kmac5/mindfulnotifier">
https://github.com/kmac5/mindfulnotifier</a>.
Please see this link for additional help, or to report any issues.

<h5>Bells</h5>
<ul>
<li>Bell 1: is from user 'steaq' via 
<a href="https://freesound.org/s/346328/">https://freesound.org/s/346328/</a>
and is licensed under the 'Creative Commons 0 License'.
</li>
<li>Bell 2: is from user 'itsallhappening' via 
<a href="https://freesound.org/people/itsallhappening/sounds/48795/">https://freesound.org/s/48795/</a>
and is licensed under the <a href="http://creativecommons.org/licenses/sampling+/1.0/">'Creative Commons Sampling+ License'</a>.
</li>
<li>Bell 3: is from user 'suburban grilla' via 
<a href="https://freesound.org/people/suburban%20grilla/sounds/2166/">https://freesound.org/s/2166/</a>
and is licensed under the <a href="http://creativecommons.org/licenses/sampling+/1.0/">'Creative Commons Sampling+ License'</a>.
</li>
<li>Bell 4: is from user 'kerri' via 
<a href="https://freesound.org/people/kerri/sounds/27421/">https://freesound.org/people/kerri/sounds/27421/</a>
and is licensed under the <a href="https://creativecommons.org/licenses/by/3.0/">'Creative Commons Attribution License'</a>.
</li>
<li>Bell 5: is from user 'dobroide' via 
<a href="https://freesound.org/people/dobroide/sounds/436976/">https://freesound.org/people/dobroide/sounds/436976/</a>
and is licensed under the <a href="https://creativecommons.org/licenses/by/3.0/">'Creative Commons Attribution License'</a>.
</li>
</ul>

<h4>License</h4>
<p>This application is licensed under ...</p>
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
