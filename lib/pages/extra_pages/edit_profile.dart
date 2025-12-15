import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:provider/provider.dart';

class EditProfile extends StatefulWidget{
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile>{
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _ageController;
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  bool _allowExit = false;

  @override   
  void initState() {
    super.initState();

    final user = Provider.of<ProfileProvider>(context, listen: false).currentUser!;
    final firebaseUser = FirebaseAuth.instance.currentUser!;

    _usernameController = TextEditingController(text: user.username);
    _bioController = TextEditingController(text: user.bio ?? "");
    _ageController = TextEditingController(text: user.age != null ? user.age.toString() : "");
    _fullNameController = TextEditingController(text: user.fullName ?? "");
    _emailController = TextEditingController(text: firebaseUser.email ?? "");

    _refreshFirebaseUser();
  }

  //refresh firebase to show possibly updated email
  Future<void> _refreshFirebaseUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if(user != null) {
        await user.reload();

        final freshUser = FirebaseAuth.instance.currentUser;

        if(mounted && freshUser != null && freshUser.email != _emailController.text) {
          _emailController.text = freshUser.email!;
        }
      }
    } catch(e) {
      rethrow;
    }
  }

  //authenticate the user in case requires-recent-login exception happens
  Future<String?> _askForPassword() async {
    final text = AppLocalizations.of(context)!;

    //show a dialog to grab users password
    String? password;
    return showDialog<String>(  
      context: context,
      builder: (context) {
        return AlertDialog(  
          title: Text(text.securityCheck),
          content: Column(  
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text.confirmPassword),
              const SizedBox(height: 10),
              TextField(  
                obscureText: true,
                onChanged: (value) => password = value,
                decoration: InputDecoration(  
                  labelText: text.password,
                  border: OutlineInputBorder(),
                )
              )
            ]
          ),
          actions: [
            TextButton(  
              onPressed: () => Navigator.pop(context,null),
              child: Text(text.cancel),
            ),
            ElevatedButton(  
              onPressed: () => Navigator.pop(context, password),
              child: Text(text.confirm),
            )
          ]
        );
      }
    );
  }
  
  //save new profile data to db and exit edit profile page
  Future<void>? _saveAndExit() async {
    final text = AppLocalizations.of(context)!;
    
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final user = profileProvider.currentUser!;
    final firebaseUser = FirebaseAuth.instance.currentUser!;

    String? newUsername;
    String? newBio;
    String? newFullName;
    int? newAge;
    String? newEmail;

    //check which variables changed
    if(_usernameController.text != user.username) {
      newUsername = _usernameController.text;
    }
    if(_emailController.text != firebaseUser.email) {
      newEmail = _emailController.text;
    }
    if(_bioController.text != user.bio) {
      newBio = _bioController.text;
    }
    if(_fullNameController.text != user.fullName) {
      newFullName = _fullNameController.text;
    }
    if(_ageController.text != user.age.toString() && _ageController.text.isNotEmpty) {
      newAge = int.tryParse(_ageController.text);
    }

    //check if something changed at all
    if(newUsername != null || newBio != null || newAge != null || newFullName != null) {
      await ApiService.updateUserData(  
        uid: user.uid,
        username: newUsername,
        bio: newBio,
        age: newAge,
        fullName: newFullName,
      );
    }

    //change email
    if(_emailController.text != firebaseUser.email && _emailController.text.isNotEmpty) {
      try {
        await firebaseUser.verifyBeforeUpdateEmail(_emailController.text);

        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(  
            SnackBar(  
              content: Text("${text.verifySend} $newEmail. ${text.checkInbox}"),
              duration: const Duration(seconds: 5),
            ),
          );
        } 
      } on FirebaseAuthException catch (e) {
        if(e.code == "requires-recent-login") {
          String? password = await _askForPassword();
          if(password != null && password.isNotEmpty) {
            try {
              AuthCredential credential = EmailAuthProvider.credential(  
                email: firebaseUser.email!,
                password: password,
              );

              await firebaseUser.reauthenticateWithCredential(credential);
              await firebaseUser.verifyBeforeUpdateEmail(_emailController.text);
              if(mounted) {
                ScaffoldMessenger.of(context).showSnackBar(  
                  SnackBar(  
                    content: Text("${text.verifySend} $newEmail. ${text.checkInbox}"),
                    duration: const Duration(seconds: 5),
                  ),
                );
              } 
            } catch (reAuthError) {
              if(mounted){
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("${text.securityCheckFailed} $reAuthError"),
                    duration: const Duration(seconds: 2)),
                  );
                return;
              }
            }
          }
        }
      } catch (e) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(  
            SnackBar(  
              content: Text("${text.failedVerifyEmail} $e"),
              duration: const Duration(seconds: 2),
            )
          );
        }
      }
    }
    profileProvider.updateLocalUser(
      username: newUsername, 
      fullName: newFullName, 
      bio: newBio, 
      age: newAge
    );

    if(mounted) {
      setState(() {
        _allowExit = true;
      });
    }
    if(mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PopScope(
        canPop: _allowExit,
        onPopInvokedWithResult: (didPop, result) async {
          if(didPop)return;
          await _saveAndExit();
        },
        child: SafeArea(
          child: Scaffold(  
            appBar: AppBar(  
              title: Text(text.editProfile),
              automaticallyImplyLeading: true,
            ),
            body: SingleChildScrollView( 
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, left: 15),
                    child: Column(  
                      spacing: 20,
                      children: [
                        TextField(controller: _usernameController,
                          decoration: InputDecoration(labelText: text.username),),
                        TextField(controller: _emailController,
                          decoration: InputDecoration(labelText: text.email),),
                        TextField(controller: _fullNameController,
                          decoration: InputDecoration(labelText: text.fullName),),
                        TextField(controller: _ageController,
                          decoration: InputDecoration(labelText: text.age),),
                        TextField(controller: _bioController,
                          decoration: InputDecoration(labelText: "Bio"),),
                      ]
                    ),
                  )
                ),
            ),
        ),
      ),
    );
  }
}