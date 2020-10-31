import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:sharekarona/HomeScreen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  
  MyApp(){
    checkPermissions();
  }
  
  void checkPermissions() async {
    bool locationPermit = await Nearby().checkLocationPermission();
    bool storagePermit = await Nearby().checkExternalStoragePermission();
    // asks for permission only if its not given

    if (!locationPermit) Nearby().askLocationPermission();
    if (!storagePermit) Nearby().askExternalStoragePermission();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(),
    );
  }
}
