/// Logs API errors so they appear in release logcat (not swallowed).
/// Call from catch (e, stack) blocks around HTTP calls.
void logApiError(Object e, StackTrace stack, [String? context]) {
  final prefix = context != null ? 'API ERROR ($context): ' : 'API ERROR: ';
  print('$prefix$e');
  print(stack);
}
