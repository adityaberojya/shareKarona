import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:math';
import 'dart:core';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

String receiverId;
String receiverName;
String serviceID = "com.sharekarona.android";

class HomeScreen extends StatefulWidget {
  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<MyFile> files;
  String myUsername, myUserId;
  Directory docsDirectory;
  String newFileName, newFilePath;
  List<Peers> myPeeps;
  Nearby mNearby;

  @override
  void initState() {
    myPeeps = new List<Peers>();
    mNearby = new Nearby();
    super.initState();

    myUsername = String.fromCharCodes(
        List.generate(10, (index) => Random().nextInt(33) + 89));

    // myUserId = String.fromCharCodes(
    // List.generate(10, (index) => Random().nextInt(10)));
    myUserId = 'micromax';
    getDocDirectory();
    getLocationPermission();

  }

  getLocationPermission() async {
    bool locs = await mNearby.checkLocationPermission();
    if(!locs){
      mNearby.askLocationPermission();
    }
    locs = await mNearby.checkLocationPermission();
    if(!locs){
      showToast("Location is disabled, the app may not function properly");
    }
  }

  tryRenameFile() {
    if (files.last.fileName.isNotEmpty &&
        files.last.filePath.isNotEmpty &&
        !files.last.saved) {
      // Both files name and file path received; Continue to rename;
      File newFile = File(files.last.filePath);
      newFile.rename(files.last.fileName);
      files.last.saved = true;
    }
  }

  void getDocDirectory() async {
    docsDirectory = await getApplicationDocumentsDirectory();
  }

  // var nearby = Nearby();

  handleIncomingPayload(String endpointId, Payload payload) {
    showToast("Incoming file from " + endpointId.toString());
    // called when the first byte of payload gets transferred.
    if (payload.type == PayloadType.BYTES) {
      // in case of bytes this object is final and it contains file name.
      newFileName = utf8.decode(payload.bytes);
      if (files.last.fileName.isNotEmpty) {
        files.add(MyFile(fileName: newFileName));
      } else {
        files.last.fileName = newFileName;
      }
    } else {
      newFilePath = payload.filePath;

      if (files.last.filePath.isNotEmpty) {
        files.add(MyFile(filePath: newFilePath));
      } else {
        files.last.filePath = newFilePath;
      }
      // file is now initiated. we will get the file in onPayloadTransfer Callback.
    }
    tryRenameFile();
  }

  handlePayloadTransfer(
      String endpointId, PayloadTransferUpdate payloadTransferUpdate) {
    double percentComplete = payloadTransferUpdate.bytesTransferred /
        payloadTransferUpdate.totalBytes *
        100;
    print("The transfer is " + percentComplete.toString() + "% Complete.");
    if (payloadTransferUpdate.status == PayloadStatus.SUCCESS) {
      // file making is complete. Now we will rename it.
      showToast("Transfer Complete");
      print("TransferComplete");
      tryRenameFile();
      // File newFile = File(newFilePath);
      // newFile.rename(newFileName);
    }
  }

  void advertise() async {
    Fluttertoast.showToast(msg: "Advertising your Device");
    try {
      bool a = await mNearby.startAdvertising(
        myUsername,
        Strategy.P2P_POINT_TO_POINT,
        onConnectionInitiated: (String id, ConnectionInfo info) {
          print("incoming connected request from " + id + info.toString());

          mNearby.acceptConnection(
            id,
            onPayLoadRecieved: handleIncomingPayload,
            onPayloadTransferUpdate: handlePayloadTransfer,
          );
        },
        onConnectionResult: (String id, Status status) async {
          print("connection to $id status " + status.toString());
          // mNearby.stopAdvertising();
        },
        onDisconnected: (String id) {
          print("disconnected from " + id);
        },  
        serviceId: "com.sharekarona.android", // uniquely identifies your app
      );

      print("Advertising try: " + a.toString());
    } catch (exception) {
      print(exception);
      // platform exceptions like unable to start bluetooth or insufficient permissions
    }
  }

  void sendFile() async {
    showToast("Starting Discovery");
    advertise();
    File toBeSent = await FilePicker.getFile();
    print(toBeSent);
    String fileName = basename(toBeSent.path);
    print(fileName);

    mNearby.sendBytesPayload(receiverId, utf8.encode("payloadId:$fileName"));
    mNearby.sendFilePayload(receiverId, toBeSent.path);
    print("file sending initiated");
  }

  void discorverPeeps() async {
    showToast("Starting Discovery !!");
    try {
      bool a = await mNearby.startDiscovery(
        myUsername,
        Strategy.P2P_POINT_TO_POINT,
        onEndpointFound: (String id, String userName, String serviceId) {
          try {
            myPeeps.add(Peers(name: userName, uid: id));
            setState((){});
            mNearby.requestConnection(
              receiverName,
              receiverId,
              onConnectionInitiated: (String id, ConnectionInfo info) {
                // Called whenever a discoverer requests connection
                print(" conection initiated " + id + info.toString());

                mNearby.acceptConnection(
                  id,
                  onPayLoadRecieved: handleIncomingPayload,
                  onPayloadTransferUpdate: handlePayloadTransfer,
                );
              },
              onConnectionResult: (endpointId, connectionInfo) {
                print("----- connection result ----- ");
                print(connectionInfo);
              },
              onDisconnected: (endpointId) {
                print("disconnected from " + endpointId.toString());
              },
            );
          } catch (e) {
            print(e);
          }
          // called when an advertiser is found
        },
        onEndpointLost: (String id) {
          //called when an advertiser is lost (only if we weren't connected to it )
        },
        serviceId: "com.yourdomain.appname", // uniquely identifies your app
      );
      print("Discovery try: " + a.toString());
    } catch (e) {
      print(e);
      // platform exceptions like unable to start bluetooth or insufficient permissions
    }
  }

  showToast(String msg) async {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      timeInSecForIosWeb: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Icon(Icons.menu),
        title: Text("Share Karona"),
        actions: <Widget>[
          Icon(Icons.history),
          SizedBox(width: 20),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: myPeeps.isEmpty ? 0 : myPeeps.length,
              itemBuilder: (context, index) {
                return AdvertiserCard(
                    username: myPeeps[index].name,
                    uid: myPeeps[index].uid,
                    serviceId: serviceID);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Center(
                child: RaisedButton(
                  onPressed: sendFile,
                  child: Text("📤 Send"),
                ),
              ),
              SizedBox(width: 10),
              Center(
                child: RaisedButton(
                  onPressed: discorverPeeps,
                  child: Text("📥 Receive"),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 10,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Center(
                child: RaisedButton(
                  onPressed: advertise,
                  child: Text("Advertise"),
                ),
              ),
              SizedBox(width: 10),
              Center(
                child: RaisedButton(
                  onPressed: discorverPeeps,
                  child: Text("Discover"),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 10,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(width: 10),
              Center(
                child: RaisedButton(
                  onPressed: () {
                    showToast("this is your name");
                  },
                  child: Text(myUsername),
                ),
              ),
              SizedBox(width: 10),
              Center(
                child: RaisedButton(
                  onPressed: () {
                    showToast("this is your id");
                  },
                  child: Text(myUserId),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 20,
          ),
        ],
      ),
    );
  }
}

class AdvertiserCard extends StatefulWidget {
  final String username, uid, serviceId;

  AdvertiserCard(
      {@required this.username, @required this.uid, @required this.serviceId});

  @override
  _AdvertiserCardState createState() => _AdvertiserCardState();
}

class _AdvertiserCardState extends State<AdvertiserCard> {
  Color color = Colors.white;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          receiverId = widget.uid;
          receiverName = widget.username;
          color = (color == Colors.green) ? Colors.white : Colors.green;
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Card(
          color: color,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: <Widget>[
                Text(widget.username),
                Text("id: " + widget.uid),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyFile {
  String fileName;
  String filePath;
  bool saved;

  MyFile({
    this.fileName = "",
    this.filePath = "",
    this.saved = false,
  });
}

class Peers {
  String name;
  String uid;

  Peers({
    this.name,
    this.uid,
  });
}
