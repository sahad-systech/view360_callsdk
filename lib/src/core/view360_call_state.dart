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

  View360CallState copyWith({
    View360CallStatus? status,
    bool? isMuted,
    bool? isSpeakerOn,
    String? roomName,
    String? error,
  }) {
    return View360CallState(
      status: status ?? this.status,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      roomName: roomName ?? this.roomName,
      error: error ?? this.error,
    );
  }
}
