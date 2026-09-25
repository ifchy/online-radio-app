/// The User-Agent sent with stream and API requests: app name, version and
/// project URL only. No device model and no identifiers.
String buildUserAgent(String version) =>
    'eRadioto/$version (Android; +https://github.com/ifchy/online-radio-app)';
