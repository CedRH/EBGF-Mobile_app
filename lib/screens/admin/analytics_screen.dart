import 'package:flutter/material.dart';
import '../../models/farm_record.dart';

/// A quick at-a-glance overview: total records, total users, records
/// added today, and a breakdown of how many records each user has
/// contributed (as proportional bars, so it's visual instead of just
/// a table of numbers).
class AnalyticsScreen extends StatelessWidget {
  final List<FarmRecord> records;

  const AnalyticsScreen({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final totalUsers = 0;
    final today = DateTime.now();
    final recordsToday = records
        .where((r) =>
            r.createdAt.year == today.year &&
            r.createdAt.month == today.month &&
            r.createdAt.day == today.day)
        .length;

    // Group records by whoever created them, for the breakdown bars.
    final Map<String, int> countsByUser = {};
    for (final r in records) {
      countsByUser[r.createdBy] = (countsByUser[r.createdBy] ?? 0) + 1;
    }
    final maxCount = countsByUser.values.isEmpty
        ? 1
        : countsByUser.values.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
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
          const Text(
            'Records by User',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
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
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: proportion,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFEDEDED),
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFFC62828)),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
