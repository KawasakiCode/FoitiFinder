//widget that contains the stream builder that grabs firebase data and changes
//gets called by main 
//is const because flutter wont rebuild it everytime we call notifyListeners 
//in settings provider. If it wasnt a const an infinite loop happens

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/main_screen.dart';
import 'package:foitifinder/pages/auth_pages/login.dart';
import 'package:foitifinder/pages/sign_up_set_up/set_up_page.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:provider/provider.dart';

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

//decides what page to push depending if user finished the initial sign up setup or not
class SetupWrapper extends StatelessWidget {
  final User firebaseUser;

  const SetupWrapper({super.key, required this.firebaseUser});

  @override 
  Widget build(BuildContext context) {
    final userProvider = Provider.of<ProfileProvider>(context);
    final currentUser = userProvider.currentUser;

    bool hasFinishedSetUp = currentUser?.hasFinishedSetUp ?? false;
    bool hasPhone = firebaseUser.phoneNumber != null && firebaseUser.phoneNumber!.isNotEmpty;

    //setup done completely, send to mainscreen
    if(hasFinishedSetUp && hasPhone) {
      return MainScreen(uid: firebaseUser.uid);
    }
    //setup not done completely, send to setup after phone number
    else if(hasPhone) {
      return const SetUpPage();
    }
    //setup not done neither phone, send to login
    else{
      //to become login
      return const SetUpPage();
    }
  }


}