//internet connection wrapper
//if it detects a connection loss it pushes a no internet page 
//when the wifi comes back again it automatically returns to the page it was

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:foitifinder/l10n/app_localizations.dart';

class InternetWrapper extends StatelessWidget{
  final Widget child;
  
  const InternetWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(  
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        if(snapshot.connectionState == ConnectionState.waiting) {
          return child;
        }

        final results = snapshot.data;
        final text = AppLocalizations.of(context)!;
        bool isConnected = results != null && results.isNotEmpty && !results.contains(ConnectivityResult.none);
        //if not internet return no wifi page
        if(!isConnected) {
          return Scaffold(  
            body: Center(  
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 100, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(text.noWifi,
                    style: TextStyle(  
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                  )),
                  SizedBox(height: 10),
                  Text(text.turnWifiOn, 
                    style: TextStyle(  
                      fontSize: 14, 
                      fontWeight: FontWeight.w400,
                  ))
                ]
              )
            )
          );
        }
        //else return the current app page
        return child;
      }
    );
  }
}
