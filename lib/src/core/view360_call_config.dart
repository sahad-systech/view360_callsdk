typedef View360TokenProvider =
    Future<String> Function({
      required String roomName,
      required String participantName,
    });

class View360CallConfig {
  final String serverUrl;
  final View360TokenProvider tokenProvider;

  const View360CallConfig({
    required this.serverUrl,
    required this.tokenProvider,
  });
}
