// ignore_for_file: prefer_const_constructors, prefer_const_declarations

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:see_you_now/globals/global.dart';

class CallLogPage extends StatefulWidget {
  const CallLogPage({super.key});

  @override
  State<CallLogPage> createState() => _CallLogPageState();
}

class _CallLogPageState extends State<CallLogPage> {
  List<Contact> _contacts = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _getContactDisplayName(String phoneNumber) {
    for (var contact in _contacts) {
      if (contact.phones!.isNotEmpty &&
          _getLast10Digits(contact.phones!.first.value.toString()) ==
              _getLast10Digits(phoneNumber)) {
        return contact.displayName ?? phoneNumber;
      }
    }

    return phoneNumber;
  }

  String _getLast10Digits(String phoneNumber) {
    if (phoneNumber.length >= 10) {
      return phoneNumber.substring(phoneNumber.length - 10);
    } else {
      return phoneNumber;
    }
  }

  Future<void> _getContacts() async {
    Iterable<Contact> contacts =
        await ContactsService.getContacts(withThumbnails: false);

    List<Contact> phoneContacts = contacts
        .where((contact) =>
            contact.phones!.isNotEmpty &&
            contact.displayName != null &&
            contact.displayName!.isNotEmpty)
        .toList();

    setState(() {
      _contacts = phoneContacts;
    });
  }

  String formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    String formattedTime =
        "${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
    return formattedTime;
  }

  @override
  void initState() {
    _getContacts();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final callLogsStream = _firestore
        .collection('callLogs')
        .where('from', isEqualTo: prefs.getString("phone"))
        .get()
        .then((querySnapshot) {
      final fromCallLogs = querySnapshot.docs;

      return _firestore
          .collection('callLogs')
          .where('to', isEqualTo: prefs.getString("phone"))
          .get()
          .then((querySnapshot2) {
        final toCallLogs = querySnapshot2.docs;
        return [...fromCallLogs, ...toCallLogs];
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: Text("Call logs"),
        backgroundColor: Colors.deepPurple.withOpacity(0.5),
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: callLogsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          var callLogs = snapshot.data;
          callLogs!.sort((a, b) => (b["timestamp"] as Timestamp)
              .compareTo(a["timestamp"] as Timestamp));
          return ListView.builder(
            itemCount: callLogs.length,
            itemBuilder: (context, index) {
              final callLog = callLogs[index].data() as Map<String, dynamic>;
              bool caller = callLog["from"] == prefs.getString("phone");
              String displayName = "";
              if (caller) {
                displayName = _getContactDisplayName(callLog["to"]);
              } else {
                displayName = _getContactDisplayName(callLog["from"]);
              }
              return Container(
                margin: EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: caller
                      ? Icon(Icons.call_made)
                      : Icon(Icons.call_received),
                  title: Text(displayName),
                  trailing: Text(
                    formatTimestamp(callLog["timestamp"]),
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
