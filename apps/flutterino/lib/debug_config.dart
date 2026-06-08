/// Central debug configuration.
///
/// Set [kDisableWebRTC] to `true` during development to skip loading the
/// `flutter_webrtc` native library entirely, which dramatically speeds up
/// hot-reload and hot-restart times.
///
/// Set [kSerialDebug] to `true` to log every USB send and every received
/// telemetry packet. Keep it `false` in normal use — debugPrint in the
/// command hot-path causes logcat backpressure and gradual lag.
///
/// ⚠️ Remember to set these back to `false` before building a release APK.
const bool kDisableWebRTC = false;
const bool kSerialDebug = false;
