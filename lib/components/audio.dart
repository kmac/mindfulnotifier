import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:audio_session/audio_session.dart';

import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/logging.dart';

var logger = Logger(printer: SimpleLogPrinter('notifier'));

const Map<String, AndroidAudioUsage> audioChannelForNotification = {
  'notification': AndroidAudioUsage.notificationEvent,
  'media': AndroidAudioUsage.media,
  'alarm': AndroidAudioUsage.alarm,
};

class NotifyAudioPlayer {
  static const String defaultBellAsset = 'media/defaultbell.mp3';
  static File customSoundFile;
  final bool disposeOnPlayStop = true;

  var _player = AudioPlayer();
  AudioSession session;

  String _audioChannelSelection;
  NotifyAudioPlayer(this._audioChannelSelection);
  NotifyAudioPlayer.useNotificationChannel() : this('notification');
  NotifyAudioPlayer.useMediaChannel() : this('media');
  NotifyAudioPlayer.useAlarmChannel() : this('alarm');

  AudioSessionConfiguration sessionConfiguration;

  void selectAudioChannel(String channel) async {
    if (audioChannelForNotification.containsKey(channel)) {
      _audioChannelSelection = channel;

      sessionConfiguration = sessionConfiguration.copyWith(
          androidAudioAttributes: AndroidAudioAttributes(
        // TODO copy this:
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.none,
        usage: audioChannelForNotification[_audioChannelSelection],
      ));
      await session.configure(sessionConfiguration);
    } else {
      throw Exception('Unknown audio channel: $channel');
    }
  }

  String getAudioChannelSelection() {
    return _audioChannelSelection;
  }

  Future<void> init() async {
    logger.i("Initializing AudioSession");

    session ??= await AudioSession.instance;

    sessionConfiguration = AudioSessionConfiguration(
      // avAudioSessionCategory: AVAudioSessionCategory.playback,
      // avAudioSessionCategoryOptions:
      //     AVAudioSessionCategoryOptions.allowBluetooth,
      // avAudioSessionMode: AVAudioSessionMode.defaultMode,
      // avAudioSessionRouteSharingPolicy:
      //     AVAudioSessionRouteSharingPolicy.defaultPolicy,
      // avSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        // contentType: AndroidAudioContentType.sonification,
        flags: AndroidAudioFlags.none,
        usage: audioChannelForNotification[_audioChannelSelection],
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      // androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
      androidWillPauseWhenDucked: false,
    );

    await session.configure(sessionConfiguration);
  }

  // Implement callbacks here. e.g. onStart, onStop, onPlay, onPause

  Future<void> play() async {
    _player ??= AudioPlayer();
    if (customSoundFile == null) {
      logger.i(
          "Playing asset=$defaultBellAsset on $_audioChannelSelection channel");
      await _player.setAsset(defaultBellAsset);
    } else {
      logger.i(
          "Playing file=${customSoundFile.path} on $_audioChannelSelection channel");
      await _player.setFilePath(customSoundFile.path);
    }
    await _player.play(); // waits until finished playing
    if (disposeOnPlayStop) {
      dispose();
    } else {
      await _player.stop(); // required to turn off _player.playing
      session
          .setActive(false); // required to allow other players to regain focus
    }
  }

  void dispose() async {
    await _player?.stop();
    await session
        ?.setActive(false); // required to allow other players to regain focus
    await _player?.dispose();
    _player = null;
  }
}
