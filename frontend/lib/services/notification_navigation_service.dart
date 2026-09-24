import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/notification.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'storage_service.dart';

class NotificationNavigationService {
  /// Handle notification tap and navigate to the appropriate screen
  static Future<void> handleNotificationTap(
    AppNotification notification,
    BuildContext context,
    User? currentUser,
  ) async {
    debugPrint('[NOTIFICATION] Tap detected');
    debugPrint('[NOTIFICATION] Type: ${notification.type}');
    debugPrint('[NOTIFICATION] Related ID: ${notification.relatedId}');
    debugPrint('[NOTIFICATION] Conversation ID: ${notification.conversationId}');
    debugPrint('[NOTIFICATION] Trip ID: ${notification.tripId}');
    debugPrint('[NOTIFICATION] Request ID: ${notification.requestId}');

    if (!context.mounted) return;

    // If user is not authenticated, store pending notification and navigate to login
    if (currentUser == null) {
      debugPrint('[NOTIFICATION] User not authenticated, storing pending notification');
      await _storePendingNotification(notification);
      if (context.mounted) {
        context.go('/login');
      }
      return;
    }

    final route = _resolveRoute(notification, currentUser);
    debugPrint('[NOTIFICATION] Target route: $route');

    if (route != null && context.mounted) {
      // Navigate without blocking on mark-as-read.
      _navigateAndMarkRead(context, route, notification);
    } else {
      debugPrint('[NOTIFICATION] Unknown notification type or missing ID, fallback to notifications list');
      if (context.mounted) {
        context.go('/notifications');
      }
    }
  }

  /// Navigate to route and mark notification as read in background
  static void _navigateAndMarkRead(BuildContext context, String route, AppNotification notification) {
    // Detail screens sit above the dashboard shell so back returns to the
    // notification list and then to the previously selected customer tab.
    final isDetailRoute = route.startsWith('/chat/') ||
        route.startsWith('/search-trip-details/') ||
        route.startsWith('/driver-return-trip-details/');
    if (isDetailRoute) {
      context.push(route);
    } else {
      context.go(route);
    }

    // Mark as read in background (fire and forget)
    if (!notification.isRead) {
      _markAsReadInBackground(notification.id);
    }
  }

  /// Mark notification as read via API (non-blocking)
  static Future<void> _markAsReadInBackground(int notificationId) async {
    try {
      final apiService = ApiService();
      await apiService.markNotificationAsRead(notificationId);
      debugPrint('[NOTIFICATION] Marked as read: $notificationId');
    } catch (e) {
      debugPrint('[NOTIFICATION] Failed to mark as read: $e');
    }
  }

  /// Resolve the target route based on notification type and user role
  static String? _resolveRoute(AppNotification notification, User currentUser) {
    final isDriver = currentUser.isDriver;
    final isCustomer = currentUser.isCustomer;

    switch (notification.type) {
      case 'delivery_confirmation_requested':
      case 'delivery_confirmed':
        return notification.conversationId == null
            ? (isDriver ? '/driver-messages' : '/customer-messages')
            : '/chat/${notification.conversationId}';
      case 'new_message':
        // Use conversationId for direct chat navigation
        final conversationId = notification.conversationId ?? notification.relatedId;
        if (conversationId != null) {
          return '/chat/$conversationId';
        }
        // Fallback to messages list
        return isDriver ? '/driver-messages' : '/customer-messages';

      case 'new_request':
        if (isDriver) {
          // Driver: go to requests list
          return '/driver-requests';
        } else if (isCustomer) {
          // Customer: go to trip details if tripId available
          final tripId = notification.tripId ?? notification.relatedId;
          if (tripId != null) {
            return '/search-trip-details/$tripId';
          }
          return '/customer-trips';
        }
        return '/notifications';

      case 'request_accepted':
        if (isDriver) {
          // Driver: go to trip details
          final tripId = notification.tripId ?? notification.relatedId;
          if (tripId != null) {
            return '/driver-return-trip-details/$tripId';
          }
          return '/driver-trips';
        } else if (isCustomer) {
          // Customer: go to chat
          final conversationId = notification.conversationId ?? notification.relatedId;
          if (conversationId != null) {
            return '/chat/$conversationId';
          }
          return '/customer-messages';
        }
        return '/notifications';

      case 'request_rejected':
        if (isDriver) {
          return '/driver-requests';
        } else if (isCustomer) {
          final tripId = notification.tripId ?? notification.relatedId;
          if (tripId != null) {
            return '/search-trip-details/$tripId';
          }
          return '/customer-trips';
        }
        return '/notifications';

      case 'request_cancelled':
        if (isDriver) {
          return '/driver-requests';
        } else if (isCustomer) {
          final tripId = notification.tripId ?? notification.relatedId;
          if (tripId != null) {
            return '/search-trip-details/$tripId';
          }
          return '/customer-trips';
        }
        return '/notifications';

      case 'trip_completed':
        return isDriver ? '/driver-history' : '/customer-history';
      case 'trip_started':
      case 'trip_cancelled':
        if (isDriver) {
          final tripId = notification.tripId ?? notification.relatedId;
          if (tripId != null) {
            return '/driver-return-trip-details/$tripId';
          }
          return '/driver-trips';
        } else if (isCustomer) {
          final tripId = notification.tripId ?? notification.relatedId;
          if (tripId != null) {
            return '/search-trip-details/$tripId';
          }
          return '/customer-trips';
        }
        return '/notifications';

      default:
        debugPrint('[NOTIFICATION] Unknown notification type: ${notification.type}');
        return '/notifications';
    }
  }

  /// Store pending notification for processing after login
  static Future<void> _storePendingNotification(AppNotification notification) async {
    try {
      final storage = StorageService();
      await storage.savePendingNotification(notification);
      debugPrint('[NOTIFICATION] Stored pending notification');
    } catch (e) {
      debugPrint('[NOTIFICATION] Failed to store pending notification: $e');
    }
  }

  /// Get and process pending notification after successful login
  /// Returns the pending notification if found, null otherwise.
  /// The caller is responsible for handling navigation with the BuildContext.
  static Future<AppNotification?> getPendingNotification() async {
    debugPrint('[NOTIFICATION] Checking for pending notification after login');
    
    final pendingNotification = await StorageService().getAndClearPendingNotification();
    if (pendingNotification != null) {
      debugPrint('[NOTIFICATION] Found pending notification');
    }
    return pendingNotification;
  }
}
