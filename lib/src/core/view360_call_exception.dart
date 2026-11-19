class View360CallException implements Exception {
  final String message;
  final Object? cause;

  const View360CallException(this.message, {this.cause});

  @override
  String toString() => 'View360CallException: $message';
}
