import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> addCallLog(String from, String to) async {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference callLogsCollection =
      _firestore.collection('callLogs');

  final DocumentReference newCallLogRef = callLogsCollection.doc();

  await newCallLogRef.set({
    'from': from,
    'to': to,
    'timestamp': Timestamp.now(),
  });
}
