//checks if the logged user does exist
//firebase automaticaly checks cached files from the phone and not the server
//this forces firebase to check with the server first

//called strictly by main.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/main_screen.dart';
import 'package:foitifinder/pages/auth_pages/login.dart';

class SessionGuard extends StatefulWidget {
  final User user;
  const SessionGuard({super.key, required this.user});

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _verifyUserStatus();
  }

  Future<void> _verifyUserStatus() async {
    try {
      //check if user exists
      //if this fails the catch block runs
      await widget.user.reload(); 
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (!FirebaseAuth.instance.currentUser!.emailVerified) {
      return const LoginPage();
    }
    return const MainScreen();
  }
}