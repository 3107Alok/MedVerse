import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/theme/theme_notifier.dart';
import 'package:frontend/theme/glassmorphism.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:frontend/widgets/empty_state_widget.dart';
import 'package:frontend/widgets/shimmer_loader.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isCleaning = true;

  @override
  void initState() {
    super.initState();
    _cleanOldNotifications();
  }

  Future<void> _cleanOldNotifications() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      if (mounted) setState(() => _isCleaning = false);
      return;
    }

    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final snapshot = await _db
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = _db.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error cleaning old notifications: $e');
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  Future<void> _clearAllNotifications(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = _db.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error clearing all notifications: $e');
    }
  }

  Future<void> _markAllAsRead(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = _db.batch();
        for (var doc in snapshot.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.isDarkMode;
    final user = authProvider.user;

    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.grey[700];

    if (user == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.getBackgroundGradient(isDark),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Notifications',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor),
          ),
          backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          actions: [
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: () => _markAllAsRead(user.uid),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear All',
              onPressed: () => _clearAllNotifications(user.uid),
            ),
          ],
        ),
        body: _isCleaning
            ? Scaffold(
                backgroundColor: Colors.transparent,
                body: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 5,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ShimmerWidget(width: double.infinity, height: 80, borderRadius: 16),
                  ),
                ),
              )
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      // Info Tip
                      GlassContainer(
                        isDarkMode: isDark,
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Note: Notifications are automatically cleared after 30 days.',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: subtitleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _cleanOldNotifications,
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _db
                                .collection('users')
                                .doc(user.uid)
                                .collection('notifications')
                                .orderBy('createdAt', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Error loading notifications',
                                    style: GoogleFonts.outfit(color: Colors.red),
                                  ),
                                );
                              }

                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return ListView.builder(
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: 5,
                                  itemBuilder: (context, index) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: ShimmerWidget(width: double.infinity, height: 80, borderRadius: 16),
                                  ),
                                );
                              }

                              final docs = snapshot.data?.docs ?? [];

                              if (docs.isEmpty) {
                                return ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 100),
                                    EmptyStateWidget(
                                      icon: Icons.notifications_none_outlined,
                                      title: 'All Caught Up!',
                                      description: 'You have no new notifications at the moment.',
                                    ),
                                  ],
                                );
                              }

                              return ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final doc = docs[index];
                                  final data = doc.data() as Map<String, dynamic>;
                                  final isRead = data['isRead'] ?? false;
                                  final timestamp = data['createdAt'] as Timestamp?;
                                  final timeStr = timestamp != null
                                      ? DateFormat('hh:mm a').format(timestamp.toDate())
                                      : '';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: Dismissible(
                                      key: Key(doc.id),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 20),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Icon(Icons.delete, color: Colors.white),
                                      ),
                                      onDismissed: (direction) {
                                        doc.reference.delete();
                                      },
                                      child: GlassContainer(
                                        isDarkMode: isDark,
                                        borderRadius: 16,
                                        border: isRead
                                            ? null
                                            : Border.all(
                                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                                width: 1.5,
                                              ),
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          leading: CircleAvatar(
                                            backgroundColor: isRead
                                                ? (isDark ? Colors.white10 : Colors.grey[100])
                                                : Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                            child: Icon(
                                              Icons.notifications,
                                              color: isRead
                                                  ? (isDark ? Colors.white54 : Colors.grey)
                                                  : Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                          title: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  data['title'] ?? 'Alert',
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                                    fontSize: 15,
                                                    color: textColor,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                timeStr,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11,
                                                  color: isDark ? Colors.white38 : Colors.grey[500],
                                                ),
                                              ),
                                            ],
                                          ),
                                          subtitle: Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              data['message'] ?? '',
                                              style: GoogleFonts.outfit(
                                                fontSize: 13,
                                                color: isRead
                                                    ? (isDark ? Colors.white60 : Colors.grey[600])
                                                    : (isDark ? Colors.white70 : Colors.black87),
                                              ),
                                            ),
                                          ),
                                          onTap: () {
                                            if (!isRead) {
                                              doc.reference.update({'isRead': true});
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
