import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum SyncOperationType { createDevice, updateAssignment, deleteDevice, createVehicle, updateVehicle, deleteVehicle }

class SyncOperation {
  final SyncOperationType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  SyncOperation({
    required this.type,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'type': type.index,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
        type: SyncOperationType.values[json['type']],
        data: json['data'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

class SyncService {
  static const _key = 'pending_operations';

  /// Add an operation to the pending queue
  static Future<void> addOperation(SyncOperationType type, Map<String, dynamic> data) async {
    final operations = await _getOperations();
    operations.add(SyncOperation(type: type, data: data, timestamp: DateTime.now()));
    await _saveOperations(operations);
  }

  /// Get all pending operations
  static Future<List<SyncOperation>> _getOperations() async {
    final jsonString = (await SharedPreferences.getInstance()).getString(_key);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => SyncOperation.fromJson(e)).toList();
  }

  /// Save operations list
  static Future<void> _saveOperations(List<SyncOperation> operations) async {
    final jsonString = json.encode(operations.map((e) => e.toJson()).toList());
    await (await SharedPreferences.getInstance()).setString(_key, jsonString);
  }

  /// Clear all pending operations
  static Future<void> clearOperations() async {
    await (await SharedPreferences.getInstance()).remove(_key);
  }

  /// Get pending operations count
  static Future<int> getPendingCount() async {
    final operations = await _getOperations();
    return operations.length;
  }

  /// Process all pending operations using the provided callbacks
  static Future<void> processPendingOperations({
    required Future<void> Function(Map<String, dynamic> data) onCreateDevice,
    required Future<void> Function(String deviceId, String assignment) onUpdateAssignment,
    required Future<void> Function(String deviceId) onDeleteDevice,
    Future<void> Function(Map<String, dynamic> data)? onCreateVehicle,
    Future<void> Function(int vehicleId, Map<String, dynamic> data)? onUpdateVehicle,
    Future<void> Function(int vehicleId)? onDeleteVehicle,
  }) async {
    final operations = await _getOperations();
    if (operations.isEmpty) return;

    final failedOperations = <SyncOperation>[];

    for (final op in operations) {
      try {
        switch (op.type) {
          case SyncOperationType.createDevice:
            await onCreateDevice(op.data);
            break;
          case SyncOperationType.updateAssignment:
            await onUpdateAssignment(op.data['deviceId'], op.data['assignment']);
            break;
          case SyncOperationType.deleteDevice:
            await onDeleteDevice(op.data['deviceId']);
            break;
          case SyncOperationType.createVehicle:
            if (onCreateVehicle != null) await onCreateVehicle(op.data);
            break;
          case SyncOperationType.updateVehicle:
            if (onUpdateVehicle != null) await onUpdateVehicle(op.data['id'], op.data);
            break;
          case SyncOperationType.deleteVehicle:
            if (onDeleteVehicle != null) await onDeleteVehicle(op.data['id']);
            break;
        }
      } catch (e) {
        failedOperations.add(op);
      }
    }

    // Keep failed operations for next sync attempt
    await _saveOperations(failedOperations);
  }
}
