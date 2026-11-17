void audioUnlock() {}
void audioSfx(String name) {}
void audioMute(bool muted) {}
void audioPause() {}
void audioResume() {}
void audioIntensity(int tier) {}
void audioAccent(String name) {}
void audioFleetIntact() {}
void audioSetLevel(String channel, String level) {}
String audioLevel(String channel) => 'full';
void audioPowerLayer(int active, bool falling) {}

// --- adaptive-soundtrack: the score player (web/audio/demon-score.js). Off the
// web there is no score: a move reports -2 (nothing plays).
double audioSong(Map<String, Object?> move) => -2;
double audioTime() => -1;
({String song, String section, double start})? audioScorePosition() => null;
