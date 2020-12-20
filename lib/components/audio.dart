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

  final _player = AudioPlayer();
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

  // static NotifyAudioPlayer _instance;

  // /// Public factory
  // static Future<NotifyAudioPlayer> getInstance() async {
  //   if (_instance == null) {
  //     _instance = NotifyAudioPlayer._create();
  //     await _instance._init();
  //   }
  //   return _instance;
  // }

  // /// Private constructor
  // NotifyAudioPlayer._create() {
  //   logger.i("Creating NotifyAudioPlayer");
  // }

  Future<void> init() async {
    logger.i("Initializing AudioSession");

    session = await AudioSession.instance;

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
        flags: AndroidAudioFlags.none,
        usage: audioChannelForNotification[_audioChannelSelection],
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    );

    await session.configure(sessionConfiguration);
  }

  // Implement callbacks here. e.g. onStart, onStop, onPlay, onPause

  Future<void> play() async {
    if (customSoundFile == null) {
      logger.i(
          "Playing asset=$defaultBellAsset on $_audioChannelSelection channel");
      await _player.setAsset(defaultBellAsset);
    } else {
      logger.i(
          "Playing file=${customSoundFile.path} on $_audioChannelSelection channel");
      await _player.setFilePath(customSoundFile.path);
    }
    // if (_player.playing) {
    //   logger.e("_player is already playing");
    //   return;
    // }
    await _player.play(); // waits until finished playing
    _player.stop(); // required to turn off _player.playing
  }

  void dispose() async {
    await _player.dispose();
  }
}

// void _entrypoint() => AudioServiceBackground.run(() => AudioPlayerTask());

// void startBackgroundAudioTask() async {
//   await AudioService.start(backgroundTaskEntrypoint: _entrypoint);
// }

// void stopBackgroundAudioTask() async {
//   await AudioService.stop();
// }

// // MAYBE I DON'T NEED THIS? I HAVE THE ALARM MANAGER
// class AudioPlayerTask extends BackgroundAudioTask {
//   static const String defaultBellAsset = 'media/defaultbell.mp3';
//   static File customSoundFile;

//   final _player = AudioPlayer(); // e.g. just_audio

//   Future<void> initSession() async {
//     logger.i("Initializing AudioSession");

//     final session = await AudioSession.instance;

//     await session.configure(AudioSessionConfiguration(
//       avAudioSessionCategory: AVAudioSessionCategory.playback,
//       // avAudioSessionCategoryOptions:
//       //     AVAudioSessionCategoryOptions.allowBluetooth,
//       avAudioSessionMode: AVAudioSessionMode.defaultMode,
//       avAudioSessionRouteSharingPolicy:
//           AVAudioSessionRouteSharingPolicy.defaultPolicy,
//       // avSetActiveOptions: AVAudioSessionSetActiveOptions.none,
//       androidAudioAttributes: const AndroidAudioAttributes(
//         contentType: AndroidAudioContentType.music,
//         flags: AndroidAudioFlags.none,
//         usage: AndroidAudioUsage.notificationEvent,
//       ),
//       androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
//       androidWillPauseWhenDucked: false,
//     ));
//   }

//   // Implement callbacks here. e.g. onStart, onStop, onPlay, onPause

//   @override
//   Future<void> onPlay() async {
//     if (customSoundFile == null) {
//       await _player.setAsset(defaultBellAsset);
//     } else {
//       await _player.setFilePath(customSoundFile.path);
//     }
//     _player.play();
//   }

//   @override
//   Future<void> onStop() {
//     _player.dispose();
//     return super.onStop();
//   }
// }
