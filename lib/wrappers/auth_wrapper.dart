//Widget that contains the stream builder that grabs firebase data and changes
//gets called by main 
//is const because flutter wont rebuild it everytime we call notifyListeners 
//in settings provider. If it wasnt a const an infinite loop happens

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/pages/auth_pages/login.dart';
import 'package:foitifinder/wrappers/setup_wrapper.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
          if(snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(  
              body: Center(  
                child: CircularProgressIndicator(),
              )
            );
          }
          if(snapshot.hasData) {
            return SetupWrapper(firebaseUser: snapshot.data!);
          } 
          return const LoginPage();
        },
    );
  }
}