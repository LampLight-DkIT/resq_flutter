// lib/features/chats/repository/dashboard_alert_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:resq/features/chats/models/dashboard_alert_model.dart';

class DashboardAlertRepository {
  final FirebaseFirestore _firestore;

  DashboardAlertRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get all dashboard alerts
  Stream<List<DashboardAlert>> getDashboardAlerts() {
    return _firestore
        .collection('dashboard_alerts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DashboardAlert.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Get unhandled dashboard alerts
  Stream<List<DashboardAlert>> getUnhandledAlerts() {
    return _firestore
        .collection('dashboard_alerts')
        .where('isHandled', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DashboardAlert.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Mark alert as handled
  Future<void> markAlertAsHandled(String alertId, String handledBy) async {
    try {
      await _firestore.collection('dashboard_alerts').doc(alertId).update({
        'isHandled': true,
        'handledBy': handledBy,
        'handledAt': FieldValue.serverTimestamp(),
        'status': 'handled',
      });
    } catch (e) {
      throw Exception('Failed to mark alert as handled: ${e.toString()}');
    }
  }

  // Get alert details
  Future<DashboardAlert> getAlertDetails(String alertId) async {
    try {
      final docSnapshot =
          await _firestore.collection('dashboard_alerts').doc(alertId).get();

      if (!docSnapshot.exists) {
        throw Exception('Alert not found');
      }

      return DashboardAlert.fromMap(
          docSnapshot.data() as Map<String, dynamic>, alertId);
    } catch (e) {
      throw Exception('Failed to get alert details: ${e.toString()}');
    }
  }
}
