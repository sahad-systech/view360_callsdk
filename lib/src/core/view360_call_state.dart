enum View360CallStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  disconnecting,
  failed,
}

class View360CallState {
  final View360CallStatus status;
  final bool isMuted;
  final bool isSpeakerOn;
  final String? roomName;
  final String? error;

  const View360CallState({
    this.status = View360CallStatus.disconnected,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.roomName,
    this.error,
  });
}
