import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../l10n/app_localizations.dart';

/// Centralized error handling service
class ErrorHandlerService {
  /// Get user-friendly error message from exception
  static String getErrorMessage(BuildContext context, dynamic error) {
    final l10n = AppLocalizations.of(context);
    
    if (error == null) {
      return l10n?.unknownError ?? 'An unknown error occurred';
    }

    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('socketexception') ||
        errorString.contains('network') ||
        errorString.contains('connection')) {
      return l10n?.networkError ?? 'Network connection error. Please check your internet connection.';
    }

    // Timeout errors
    if (errorString.contains('timeout')) {
      return l10n?.timeoutError ?? 'Request timed out. Please try again.';
    }

    // Server errors
    if (errorString.contains('500') || errorString.contains('internal server error')) {
      return l10n?.serverError ?? 'Server error. Please try again later.';
    }

    // Authentication errors
    if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return l10n?.unauthorizedError ?? 'Authentication failed. Please log in again.';
    }

    // Not found errors
    if (errorString.contains('404') || errorString.contains('not found')) {
      return l10n?.notFoundError ?? 'Resource not found.';
    }

    // Validation errors
    if (errorString.contains('validation') || errorString.contains('invalid')) {
      return l10n?.validationError ?? 'Invalid data provided. Please check your input.';
    }

    // Rate limiting
    if (errorString.contains('429') || errorString.contains('rate limit')) {
      return l10n?.rateLimitError ?? 'Too many requests. Please wait a moment and try again.';
    }

    // Default: return the error message or a generic one
    if (error is String) {
      return error;
    }

    return l10n?.unknownError ?? 'An error occurred: ${error.toString()}';
  }

  /// Show error snackbar
  static void showError(BuildContext context, dynamic error) {
    try {
      final message = getErrorMessage(context, error);
      final theme = Theme.of(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: theme.colorScheme.error,
          duration: const Duration(seconds: 4),
          // Removed action button to avoid context deactivation issues
          // SnackBar will auto-dismiss after 4 seconds
        ),
      );
    } catch (e) {
      // Context is deactivated or ScaffoldMessenger not available, just log the error
      if (kDebugMode) {
        print('Could not show error snackbar: $e');
      }
    }
  }

  /// Show error dialog
  static Future<void> showErrorDialog(
    BuildContext context,
    dynamic error, {
    String? title,
    VoidCallback? onRetry,
  }) async {
    final l10n = AppLocalizations.of(context);
    final message = getErrorMessage(context, error);

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? (l10n?.error ?? 'Error')),
        content: Text(message),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: Text(l10n?.retry ?? 'Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.ok ?? 'OK'),
          ),
        ],
      ),
    );
  }

  /// Log error (for debugging and analytics)
  static void logError(dynamic error, {StackTrace? stackTrace, String? context}) {
    if (kDebugMode) {
      print('=== ERROR ===');
      if (context != null) {
        print('Context: $context');
      }
      print('Error: $error');
      if (stackTrace != null) {
        print('Stack Trace: $stackTrace');
      }
      print('=============');
    }
    // TODO: Add analytics/crash reporting integration
  }

  /// Handle API error with retry logic
  static Future<T?> handleApiError<T>(
    BuildContext context,
    Future<T> Function() apiCall, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await apiCall();
      } catch (e) {
        attempts++;
        logError(e, context: 'API Call (attempt $attempts/$maxRetries)');
        
        if (attempts >= maxRetries) {
          showError(context, e);
          return null;
        }
        
        // Wait before retrying
        await Future.delayed(retryDelay * attempts);
      }
    }
    
    return null;
  }
}
