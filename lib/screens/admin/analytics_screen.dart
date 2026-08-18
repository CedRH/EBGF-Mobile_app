import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/audit_log_entry.dart';
import '../../models/farm_record.dart';
import '../../services/records_service.dart';
import '../../services/user_service.dart';
import '../../services/audit_log_service.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FarmRecord>>(
      stream: RecordsService.instance.recordsStream,
      builder: (context, recordsSnap) {
        final records = recordsSnap.data ?? [];
        return StreamBuilder<List<AppUser>>(
          stream: UserService.instance.usersStream,
          builder: (context, usersSnap) {
            final totalUsers = usersSnap.data?.length ?? 0;
            return StreamBuilder<List<AuditLogEntry>>(
              stream: AuditLogService.instance.auditLogStream(limit: 5),
              builder: (context, auditSnap) {
                final recentActivity = (auditSnap.data ?? []).take(5).toList();

                final today = DateTime.now();
                final recordsToday = records
                    .where((r) =>
                        r.createdAt.year == today.year &&
                        r.createdAt.month == today.month &&
                        r.createdAt.day == today.day)
                    .length;

                final Map<String, int> countsByUser = {};
                for (final r in records) {
                  countsByUser[r.createdBy] =
                      (countsByUser[r.createdBy] ?? 0) + 1;
                }
                final maxCount = countsByUser.values.isEmpty
                    ? 1
                    : countsByUser.values.reduce((a, b) => a > b ? a : b);

                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Analytics'),
                    actions: const [
                      Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Center(child: _LiveBadge()),
                      ),
                    ],
                  ),
                  body: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Total Records',
                              value: '${records.length}',
                              color: const Color(0xFF2E7D32),
                              icon: Icons.list_alt,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Total Users',
                              value: '$totalUsers',
                              color: const Color(0xFF6A1B9A),
                              icon: Icons.people_alt_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _StatCard(
                        label: 'Records Added Today',
                        value: '$recordsToday',
                        color: const Color(0xFFC62828),
                        icon: Icons.today,
                      ),
                      const SizedBox(height: 28),
                      const Text('Records by User',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (countsByUser.isEmpty)
                        const Text('No records yet.',
                            style: TextStyle(color: Colors.black54))
                      else
                        ...countsByUser.entries.map((entry) {
                          final proportion = entry.value / maxCount;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${entry.key}  (${entry.value})',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: proportion,
                                    minHeight: 10,
                                    backgroundColor: const Color(0xFFEDEDED),
                                    valueColor: const AlwaysStoppedAnimation(
                                        Color(0xFFC62828)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 28),
                      const Text('Recent Activity',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (recentActivity.isEmpty)
                        const Text('No activity yet.',
                            style: TextStyle(color: Colors.black54))
                      else
                        ...recentActivity.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: entry.action.color
                                        .withValues(alpha: 0.15),
                                    child: Icon(entry.action.icon,
                                        size: 15, color: entry.action.color),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.action.label,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'by ${entry.performedBy}',
                                          style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Colors.black54),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (entry.description.isNotEmpty &&
                                            entry.description !=
                                                'Signed in') ...[
                                          const SizedBox(height: 1),
                                          Text(
                                            entry.description,
                                            style: const TextStyle(
                                                fontSize: 11.5,
                                                color: Colors.black38),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: Tween(begin: 0.3, end: 1.0).animate(_controller),
          child: const CircleAvatar(
              radius: 4, backgroundColor: Colors.greenAccent),
        ),
        const SizedBox(width: 6),
        const Text('LIVE',
            style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF991F0A).withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
    );
  }
}
