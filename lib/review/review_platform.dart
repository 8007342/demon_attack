import 'review_platform_stub.dart'
    if (dart.library.js_interop) 'review_platform_web.dart'
    as platform;

/// The few browser features the review studio needs: notes that outlive a
/// reload, a file download for the notes export, and an audio element with a
/// playhead. Off the web (tests) these are in memory, so nothing here can fail
/// a test. Same shape as kumbia-kombat's console browser adapter.
abstract class ReviewPlatform {
  String? read(String key);
  void write(String key, String value);

  /// Saves [text] as a file called [filename] (the browser's download).
  void download(String filename, String text, {String type});

  ReviewAudio audio();
}

/// One sound at a time from a URL (relative to the page's base).
abstract class ReviewAudio {
  void play(String url);
  void pause();
  void resume();
  void seek(double seconds);
  bool get playing;
  double get position;

  /// NaN until the browser has read the file's length.
  double get duration;
  void dispose();
}

ReviewPlatform createReviewPlatform() => platform.createPlatform();
