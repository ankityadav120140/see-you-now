// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:see_you_now/globals/global.dart';
import 'package:see_you_now/pages/call_page.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

import '../services/add_call_log.dart';
import 'auth_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Contact> _contacts = [];
  List<String> _appUsers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _getAppUsers();
    _getContacts();
    _searchQuery = '';
  }

  Future<void> _getAppUsers() async {
    setState(() {
      loading = true;
    });
    List<String> appUsers = [];
    QuerySnapshot<Map<String, dynamic>> querySnapshot =
        await FirebaseFirestore.instance.collection('users').get();
    querySnapshot.docs.forEach((doc) {
      appUsers.add(doc.data()['phone'].toString());
    });
    setState(() {
      _appUsers = appUsers;
    });
  }

  Future<void> _getContacts() async {
    await requestContactsPermission();
    Iterable<Contact> contacts = await ContactsService.getContacts(
      withThumbnails: true,
      androidLocalizedLabels: true,
      orderByGivenName: true,
    );

    List<String> formattedAppUsers =
        _appUsers.map((phoneNumber) => _getLast10Digits(phoneNumber)).toList();

    List<Contact> phoneContacts =
        contacts.where((contact) => contact.phones!.isNotEmpty).toList();

    List<Contact> appContacts = [];

    phoneContacts.forEach((contact) {
      for (var phone in contact.phones!) {
        if (formattedAppUsers.contains(
            _getLast10Digits(removeSpacesFromPhoneNumber(phone.value!)))) {
          String displayName = contact.displayName ?? "No Name";
          String phoneNumber = _getLast10Digits(phone.value!);
          Contact customContact = Contact(
            displayName: displayName,
            phones: [Item(value: phoneNumber)],
          );
          appContacts.add(customContact);
          break;
        }
      }
    });

    setState(() {
      _contacts = appContacts;
      // _contacts = phoneContacts;
      loading = false;
    });
  }

  String removeSpacesFromPhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(' ', '');
  }

  String _getLast10Digits(String phoneNumber) {
    if (phoneNumber.length >= 10) {
      return phoneNumber.substring(phoneNumber.length - 10);
    } else {
      return phoneNumber;
    }
  }

  Future<void> requestContactsPermission() async {
    final PermissionStatus status = await Permission.contacts.request();
    if (status.isGranted) {
    } else if (status.isDenied) {
      // Handle denied permission
      print('Contacts permission denied.');
    } else if (status.isPermanentlyDenied) {
      // Handle permanently denied permission
      print('Contacts permission permanently denied.');
    }
  }

  String mergeLast10Digits(String phoneNumber1, String phoneNumber2) {
    String last10Digits1 = phoneNumber1.substring(phoneNumber1.length - 10);
    String last10Digits2 = phoneNumber2.substring(phoneNumber2.length - 10);

    List<String> digitsList = [];
    digitsList.addAll(last10Digits1.split(''));
    digitsList.addAll(last10Digits2.split(''));
    digitsList.sort();

    return digitsList.join();
  }

  bool loading = false;
  bool onCall = false;
  late DateTime startCall;
  late DateTime endCall;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Contacts",
            ),
            IconButton(
              onPressed: () async {
                FirebaseAuth _auth = FirebaseAuth.instance;
                try {
                  await _auth.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => AuthPage()),
                  );
                } catch (e) {
                  print("Error during logout: $e");
                }
              },
              icon: Icon(Icons.logout),
            )
          ],
        ),
        backgroundColor: Colors.deepPurple.withOpacity(0.4),
      ),
      body: loading
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                ),
                CircularProgressIndicator(),
                SizedBox(
                  height: 30,
                ),
                Text(
                  "Refreshing Contacts",
                )
              ],
            )
          : Container(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(10),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search contacts...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _contacts.isNotEmpty
                        ? ListView.builder(
                            itemCount: _contacts.length,
                            itemBuilder: (BuildContext context, int index) {
                              Contact contact = _contacts[index];
                              if (_searchQuery.isNotEmpty &&
                                  !contact.displayName!
                                      .toLowerCase()
                                      .contains(_searchQuery.toLowerCase())) {
                                return Container();
                              }
                              if (prefs.getString("phone") ==
                                  _getLast10Digits(
                                      contact.phones!.first.value!)) {
                                return Container();
                              }
                              return Container(
                                margin: EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    border: Border.all(
                                      color: Colors.blue,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  title: Text(contact.displayName!),
                                  subtitle: Text(_getLast10Digits(
                                      contact.phones!.first.value!)),
                                  trailing: ZegoSendCallInvitationButton(
                                    onPressed: (code, message, p2) {
                                      print("Adding call log");
                                      String from = prefs.getString("phone")!;
                                      String to = contact.phones!.first.value!;
                                      addCallLog(from, to);
                                    },
                                    buttonSize: Size(80, 80),
                                    iconSize: Size(50, 50),
                                    isVideoCall: true,
                                    invitees: [
                                      ZegoUIKitUser(
                                        id: contact.phones!.first.value!,
                                        name: contact.displayName!,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Text(
                                "None of your contacts are using See You Now"),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CallPage(
                          callID: "0",
                          userID: prefs.getString("phone")!,
                          UserName: prefs.getString("name")!)));
            },
            label: Text("Join Universal Call"),
          ),
          FloatingActionButton(
            onPressed: () {
              _getAppUsers();
              _getContacts();
            },
            child: Icon(Icons.replay_outlined),
          ),
        ],
      ),
    );
  }
}
