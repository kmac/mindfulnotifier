import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

import 'package:mindfulnotifier/screens/sound.dart';
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/logging.dart';

var logger = createLogger('audio');

const Map<String, AndroidAudioUsage> audioChannelForNotification = {
  'notification': AndroidAudioUsage.notificationEvent,
  'media': AndroidAudioUsage.media,
  'alarm': AndroidAudioUsage.alarm,
  // 'ringtone': AndroidAudioUsage.notificationRingtone,
};

class NotifyAudioPlayer {
  static const String defaultBellAsset = 'media/tibetan_bell_ding_b.mp3';
  final bool disposeOnPlayStop = true;

  var _player = AudioPlayer();
  AudioSession _session;

  final String audioChannelSelection;
  NotifyAudioPlayer(this.audioChannelSelection);
  NotifyAudioPlayer.useNotificationChannel() : this('notification');
  NotifyAudioPlayer.useMediaChannel() : this('media');
  NotifyAudioPlayer.useAlarmChannel() : this('alarm');

  AudioSessionConfiguration _sessionConfiguration;

  Future<void> init() async {
    logger.i("Initializing AudioSession");

    _session ??= await AudioSession.instance;

    _sessionConfiguration = AudioSessionConfiguration(
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.none,
        usage: audioChannelForNotification[audioChannelSelection],
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      // androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
      androidWillPauseWhenDucked: false,
    );

    await _session.configure(_sessionConfiguration);
  }

  Future<void> playBell() async {
    ScheduleDataStore ds = await ScheduleDataStore.getInstance();
    String bellId = ds.bellId;
    logger.i("playBellId: $bellId");
    if (bellId == 'customBell') {
      play(File(ds.customBellPath));
    } else {
      play(bellDefinitions[bellId]['path']);
    }
  }

  Future<void> play(dynamic fileOrPath) async {
    String assetToPlay;
    File fileToPlay;
    _player ??= AudioPlayer();
    if (_player.playing) {
      logger.d("already playing; ignoring 'play $fileOrPath'");
      return;
    }
    if (fileOrPath != null) {
      if (fileOrPath is String) {
        // this is an asset
        assetToPlay = fileOrPath;
      } else if (fileOrPath is File) {
        // this is a custom file
        fileToPlay = fileOrPath;
      }
    }
    if (fileToPlay == null) {
      if (assetToPlay == null || assetToPlay == '') {
        logger.d("play: defaulting to default: $defaultBellAsset");
        assetToPlay = defaultBellAsset;
      }
      logger.i("Playing asset=$assetToPlay on $audioChannelSelection channel");
      await _player.setAsset(assetToPlay);
    } else {
      logger.i(
          "Playing file=${fileToPlay.path} on $audioChannelSelection channel");
      await _player.setFilePath(fileToPlay.path);
    }
    await _player.play(); // waits until finished playing
    if (disposeOnPlayStop) {
      dispose();
    } else {
      await _player.stop(); // required to turn off _player.playing
      _session
          .setActive(false); // required to allow other players to regain focus
    }
  }

  Future<void> dispose() async {
    logger.d("AudioPlayer dispose");
    await _player?.stop();
    await _session
        ?.setActive(false); // required to allow other players to regain focus
    await _player?.dispose();
    _player = null;
  }
}
