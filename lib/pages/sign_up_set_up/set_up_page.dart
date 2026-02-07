import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/main_screen.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/widgets/delayed_inkwell.dart';
import 'package:provider/provider.dart';

class SetUpPage extends StatefulWidget {
  const SetUpPage({super.key});

  @override
  State<SetUpPage> createState() => _SetUpPageState();
}

class _SetUpPageState extends State<SetUpPage> {
  late TextEditingController _bioController;
  late TextEditingController _ageController;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<ProfileProvider>(
      context,
      listen: false,
    ).currentUser!;

    _bioController = TextEditingController(text: user.bio ?? "");
    _ageController = TextEditingController(
      text: user.age != null ? user.age.toString() : "",
    );
  }

  void confirmAndExit() async {
    final user = Provider.of<ProfileProvider>(context, listen: false).currentUser!;

    String? newBio;
    int? newAge;

    if(_bioController.text != user.bio) {
      newBio = _bioController.text;
    }
    if(_ageController.text != user.age.toString() && _ageController.text.isNotEmpty) {
      newAge = int.tryParse(_ageController.text);
    }

    if(newBio != null || newAge != null) {
      await ApiService.updateUserData(  
        uid: user.uid,
        bio: newBio,
        age: newAge,
        hasFinishedSetUp: true,
      );
    } else {
      await ApiService.updateUserData(
        uid: user.uid,
        hasFinishedSetUp: true,);
    }

    if(!mounted)return;
    Navigator.pushAndRemoveUntil( 
      context,
      MaterialPageRoute(  
        builder: (context) => MainScreen(uid: user.uid)
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final settings = Provider.of<SettingsProvider>(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(text.editProfile, style: TextStyle(fontSize: 20)),
                TextButton(  
                  onPressed: () => confirmAndExit(),
                  child: Text("Skip", style: TextStyle(fontSize: 20)),
                )
              ],
            ),
            automaticallyImplyLeading: true,
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, left: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //age controller
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 7),
                    child: Text(
                      text.addAge,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, right: 10),
                    child: TextField(
                      controller: _ageController,
                      decoration: InputDecoration(labelText: text.age),
                    ),
                  ),
                  //bio controller
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 7),
                    child: Text(
                      text.addBio,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, right: 10),
                    child: TextField(
                      controller: _bioController,
                      decoration: InputDecoration(labelText: "Bio"),
                    ),
                  ),
                  //interests
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      text.interests,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 15, top: 15),
                    child: Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: DelayedInkWell(
                        delayMs: 170,
                        onTap: () => settings.addRemoveInterests("Men"),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                            bottom: 8,
                            left: 10,
                            right: 15,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                text.men,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (settings.interests.contains("Men"))
                                Image.asset(
                                  'assets/icons/check.png',
                                  width: 20,
                                  height: 20,
                                )
                              else
                                const SizedBox(width: 20, height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 15, top: 15),
                    child: Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: DelayedInkWell(
                        delayMs: 170,
                        onTap: () => settings.addRemoveInterests("Women"),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                            bottom: 8,
                            left: 10,
                            right: 15,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                text.women,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (settings.interests.contains("Women"))
                                Image.asset(
                                  'assets/icons/check.png',
                                  width: 20,
                                  height: 20,
                                )
                              else
                                const SizedBox(width: 20, height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 15, top: 15),
                    child: Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: DelayedInkWell(
                        delayMs: 170,
                        onTap: () => settings.addRemoveInterests("Everyone"),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                            bottom: 8,
                            left: 10,
                            right: 15,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                text.everybody,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (settings.interests.contains("Everyone"))
                                Image.asset(
                                  'assets/icons/check.png',
                                  width: 20,
                                  height: 20,
                                )
                              else
                                const SizedBox(width: 20, height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  //age range
                  Padding(
                    padding: const EdgeInsets.only(top: 20, right: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          text.ageRange,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${settings.ageRange.start.toInt()} - ${settings.ageRange.end.toInt()}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RangeSlider(
                    values: settings.ageRange,
                    min: 18,
                    max: 100,
                    divisions: 82,
                    onChanged: (v) => settings.saveAgeRange(v),
                  ),
                  //gender
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      text.addGender,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 15, top: 15),
                    child: Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: DelayedInkWell(
                        delayMs: 150,
                        onTap: () => settings.changeGender("Male"),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                            bottom: 8,
                            left: 10,
                            right: 15,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                text.male,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (settings.gender == "Male")
                                Image.asset(
                                  'assets/icons/check.png',
                                  width: 20,
                                  height: 20,
                                )
                              else
                                const SizedBox(width: 20, height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 15, top: 15),
                    child: Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.grey, width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: DelayedInkWell(
                        delayMs: 150,
                        onTap: () => settings.changeGender("Female"),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                            bottom: 8,
                            left: 10,
                            right: 15,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                text.female,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (settings.gender == "Female")
                                Image.asset(
                                  'assets/icons/check.png',
                                  width: 20,
                                  height: 20,
                                )
                              else
                                const SizedBox(width: 20, height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  //confirm button
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Align(
                      alignment: Alignment.center,
                      child: TextButton(  
                        onPressed: () => confirmAndExit(),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF8A2BE2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 10
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              12,
                            ),
                          ),
                        ),
                        child: Text(text.confirm, style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
