//The initial setup after the user sing's up
//Here the user needs to provide their phone number
//Phone number is required because it is harder to fill the app with bots
//General information and settings can also be given in this page
//like bio, age, interests etc...

//This page is shown only once after the user sign's up.
//If the user quits the app while in this page then the app will
//launch here next time

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/main_screen.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/utils/age.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/widgets/nav_row.dart';
import 'package:foitifinder/widgets/polish.dart';
import 'package:provider/provider.dart';
import 'package:foitifinder/widgets/loading_overlay.dart';
import 'package:foitifinder/widgets/primary_button.dart';

class SetUpPage extends StatefulWidget {
  const SetUpPage({super.key});

  @override
  State<SetUpPage> createState() => _SetUpPageState();
}

class _SetUpPageState extends State<SetUpPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  bool _isLoading = false;
  late TextEditingController _bioController;
  DateTime? _birthday;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<ProfileProvider>(
      context,
      listen: false,
    ).currentUser!;

    _bioController = TextEditingController(text: user.bio ?? "");
    _birthday = user.birthday;
  }

  //Pick a birthday. Bounded at 18 years ago so an under-age date cannot be
  //chosen at all: an invalid value is unreachable rather than rejected after
  //the fact.
  Future<void> _pickBirthday() async {
    final latest = birthdayForAge(18);
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? birthdayForAge(20),
      firstDate: birthdayForAge(100),
      lastDate: latest,
      helpText: text.birthday,
    );
    if (picked == null) return;
    setState(() => _birthday = picked);
  }

  //Put user data if available in the database
  void confirmAndExit() async {
    final user = Provider.of<ProfileProvider>(
      context,
      listen: false,
    ).currentUser!;
    final settings = Provider.of<SettingsProvider>(  
      context, 
      listen: false,
    );

    String? newBio;
    DateTime? newBirthday;

    if (_bioController.text != user.bio) {
      newBio = _bioController.text;
    }
    //the picker cannot return an out of range date, so there is nothing left
    //to validate here - only whether it changed
    if (_birthday != user.birthday) {
      newBirthday = _birthday;
    }

    setState(() {
      _isLoading = true;
    });

    if (newBio != null || newBirthday != null) {
      await ApiService.updateUserData(
        uid: user.uid,
        bio: newBio,
        birthday: newBirthday,
        hasFinishedSetUp: true,
      );
    }

    await settings.confirmOnSetUp();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => MainScreen(uid: user.uid)),
      (route) => false,
    );
  }

  void skipSetUp() async {
    final settings = Provider.of<SettingsProvider>(  
      context,
      listen: false,
    );
    final user = Provider.of<ProfileProvider>(
      context,
      listen: false,
    ).currentUser!;

    setState(() {
      _isLoading = true;
    });
    try {
      await ApiService.updateUserData(uid: user.uid, hasFinishedSetUp: true);
      await settings.clearSkipOnSetUp();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => MainScreen(uid: user.uid)),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.errorOccured), backgroundColor: Colors.red),
      );
    }
  }

  //UI
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        appBar: PageAppBar(
          title: text.editProfile,
          actions: [
            SpringPress(
              child: TextButton(
                onPressed: () => skipSetUp(),
                child: const Text("Skip"),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: LoadingOverlay(
          isLoading: _isLoading,
          child: GlassScroll(
            slivers: [
              SliverStagger(
                padding: EdgeInsets.zero,
                children: [
                  //Age controller
                  SectionHeader(text.addAge),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    //a read-only field that opens the picker: typing a date
                    //invites every ambiguous format there is
                    child: SpringPress(
                      child: InkWell(
                        onTap: _pickBirthday,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: text.birthday,
                            suffixIcon: const Icon(
                              Icons.calendar_today,
                              size: 24,
                            ),
                          ),
                          child: Text(
                            _birthday == null
                                ? ''
                                : '${_birthday!.day}/${_birthday!.month}/${_birthday!.year}',
                          ),
                        ),
                      ),
                    ),
                  ),
                  //Bio controller
                  SectionHeader(text.addBio),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _bioController,
                      decoration: InputDecoration(labelText: "Bio"),
                    ),
                  ),
                  //Interests
                  SectionHeader(text.interests),
                  CardGroup(
                    dividers: true,
                    children: [
                      CheckRow(
                        label: text.men,
                        selected: settings.preferredGender.contains("Men"),
                        onTap: () => settings.addRemovePreferredGender(
                          "Men",
                          saveToDb: false,
                        ),
                      ),
                      CheckRow(
                        label: text.women,
                        selected: settings.preferredGender.contains("Women"),
                        onTap: () => settings.addRemovePreferredGender(
                          "Women",
                          saveToDb: false,
                        ),
                      ),
                      CheckRow(
                        label: text.everybody,
                        selected: settings.preferredGender.contains("Everyone"),
                        onTap: () => settings.addRemovePreferredGender(
                          "Everyone",
                          saveToDb: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  //Age range
                  CardGroup(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  text.ageRange,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  '${settings.ageRange.start.toInt()} - ${settings.ageRange.end.toInt()}',
                                  style: mutedText(context),
                                ),
                              ],
                            ),
                            RangeSlider(
                              values: settings.ageRange,
                              min: 18,
                              max: 100,
                              divisions: 82,
                              onChanged: (v) =>
                                  settings.saveAgeRange(v, saveToDb: false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  //Gender
                  SectionHeader(text.addGender),
                  CardGroup(
                    dividers: true,
                    children: [
                      CheckRow(
                        label: text.male,
                        selected: settings.gender == "Male",
                        onTap: () =>
                            settings.changeGender("Male", saveToDb: false),
                      ),
                      CheckRow(
                        label: text.female,
                        selected: settings.gender == "Female",
                        onTap: () =>
                            settings.changeGender("Female", saveToDb: false),
                      ),
                    ],
                  ),
                  //Confirm button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: PrimaryButton(
                      label: text.confirm,
                      onPressed: () => confirmAndExit(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
