import 'package:flutter/material.dart';

/// Every kind of action we track in the Audit Log.
///
/// Using an enum (instead of a raw String) means the compiler catches
/// typos, and it lets us attach a consistent color + icon to each action
/// type in one place below, instead of scattering `if` checks everywhere
/// the log is displayed.
enum AuditActionType {
  login,
  createRecord,
  editRecord,
  deleteRecord,
  promoteUser,
  demoteUser,
  deleteUser,
  updateFieldConfig,
  approveUser,
  rejectUser,
}

/// Small helper so the UI can say `entry.action.color` / `.icon` / `.label`
/// instead of re-implementing a switch statement in every screen.
extension AuditActionTypeX on AuditActionType {
  String get label {
    switch (this) {
      case AuditActionType.login:
        return 'Logged In';
      case AuditActionType.createRecord:
        return 'Created Record';
      case AuditActionType.editRecord:
        return 'Edited Record';
      case AuditActionType.deleteRecord:
        return 'Deleted Record';
      case AuditActionType.promoteUser:
        return 'Promoted User';
      case AuditActionType.demoteUser:
        return 'Demoted User';
      case AuditActionType.deleteUser:
        return 'Deleted User';
      case AuditActionType.updateFieldConfig:
        return 'Updated Field Labels';
      case AuditActionType.approveUser:
        return 'Approved User';
      case AuditActionType.rejectUser:
        return 'Rejected User';
    }
  }

  Color get color {
    switch (this) {
      case AuditActionType.login:
        return const Color(0xFF1565C0); // blue
      case AuditActionType.createRecord:
        return const Color(0xFF2E7D32); // green
      case AuditActionType.editRecord:
        return const Color(0xFFF9A825); // amber
      case AuditActionType.deleteRecord:
        return const Color(0xFFC62828); // red
      case AuditActionType.promoteUser:
        return const Color(0xFF6A1B9A); // purple
      case AuditActionType.demoteUser:
        return const Color(0xFF616161); // grey
      case AuditActionType.deleteUser:
        return const Color(
            0xFF8B0000); // dark red — distinct from record-delete red
      case AuditActionType.updateFieldConfig:
        return const Color(0xFF00838F); // teal
      case AuditActionType.approveUser:
        return const Color(0xFF2E7D32); // green
      case AuditActionType.rejectUser:
        return const Color(0xFFC62828); // red
    }
  }

  IconData get icon {
    switch (this) {
      case AuditActionType.login:
        return Icons.login;
      case AuditActionType.createRecord:
        return Icons.add_circle_outline;
      case AuditActionType.editRecord:
        return Icons.edit_outlined;
      case AuditActionType.deleteRecord:
        return Icons.delete_outline;
      case AuditActionType.promoteUser:
        return Icons.arrow_upward;
      case AuditActionType.demoteUser:
        return Icons.arrow_downward;
      case AuditActionType.deleteUser:
        return Icons.person_remove_outlined;
      case AuditActionType.updateFieldConfig:
        return Icons.label_outline;
      case AuditActionType.approveUser:
        return Icons.check_circle_outline;
      case AuditActionType.rejectUser:
        return Icons.cancel_outlined;
    }
  }
}

class AuditLogEntry {
  final String id;
  final AuditActionType action;
  final String performedBy; // email of whoever did it
  final String description; // human-readable detail, e.g. "Tag #A123"
  final DateTime timestamp;

  AuditLogEntry({
    required this.id,
    required this.action,
    required this.performedBy,
    required this.description,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'action': action.name,
      'performedBy': performedBy,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) {
    final rawTimestamp = map['timestamp'];
    final timestamp = rawTimestamp is String
        ? DateTime.parse(rawTimestamp)
        : (rawTimestamp is DateTime
            ? rawTimestamp
            : DateTime.fromMillisecondsSinceEpoch(
                rawTimestamp.millisecondsSinceEpoch));

    return AuditLogEntry(
      id: map['id'] as String,
      action: AuditActionType.values.firstWhere(
        (type) => type.name == map['action'] as String,
        orElse: () => AuditActionType.login,
      ),
      performedBy: map['performedBy'] as String,
      description: map['description'] as String,
      timestamp: timestamp,
    );
  }
}
