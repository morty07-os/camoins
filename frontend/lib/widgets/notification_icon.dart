import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';

final unreadNotificationsProvider = FutureProvider<int>((ref) async {
  final apiService = ApiService();
  try {
    final response = await apiService.getNotifications(limit: 1);
    return response.unreadCount;
  } catch (_) {
    return 0;
  }
});

class NotificationIcon extends ConsumerWidget {
  final double size;
  final Color? color;

  const NotificationIcon({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadNotificationsProvider);

    return unreadCountAsync.when(
      data: (unreadCount) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                unreadCount > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                size: size,
                color: color,
              ),
              tooltip: 'Notifications',
              onPressed: () => context.go('/notifications'),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onError,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => IconButton(
        icon: Icon(Icons.notifications_none_rounded, size: size, color: color),
        tooltip: 'Notifications',
        onPressed: () => context.go('/notifications'),
      ),
      error: (_, __) => IconButton(
        icon: Icon(Icons.notifications_none_rounded, size: size, color: color),
        tooltip: 'Notifications',
        onPressed: () => context.go('/notifications'),
      ),
    );
  }
}

class NotificationIconWithCount extends ConsumerWidget {
  final double iconSize;
  final double badgeSize;
  final Color? iconColor;
  final Color? badgeColor;
  final VoidCallback? onTap;

  const NotificationIconWithCount({
    super.key,
    this.iconSize = 24,
    this.badgeSize = 16,
    this.iconColor,
    this.badgeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadNotificationsProvider);

    return unreadCountAsync.when(
      data: (unreadCount) {
        return GestureDetector(
          onTap: onTap ?? () => context.go('/notifications'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                unreadCount > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                size: iconSize,
                color: iconColor,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: BoxConstraints(
                      minWidth: badgeSize,
                      minHeight: badgeSize,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor ?? Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(badgeSize / 2),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onError,
                          fontSize: badgeSize * 0.6,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => GestureDetector(
        onTap: onTap ?? () => context.go('/notifications'),
        child: Icon(
          Icons.notifications_none_rounded,
          size: iconSize,
          color: iconColor,
        ),
      ),
      error: (_, __) => GestureDetector(
        onTap: onTap ?? () => context.go('/notifications'),
        child: Icon(
          Icons.notifications_none_rounded,
          size: iconSize,
          color: iconColor,
        ),
      ),
    );
  }
}