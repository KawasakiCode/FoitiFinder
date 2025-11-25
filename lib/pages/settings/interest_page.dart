import 'package:flutter/material.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';

Set<String> _selectedInterests = {};

class InterestPage extends StatefulWidget {
  const InterestPage({super.key});

  @override
  State<InterestPage> createState() => _InterestPageState();
}

class _InterestPageState extends State<InterestPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext buildContext) {
    final settings = Provider.of<SettingsProvider>(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, dynamic result) async {
        if (didPop) return;
          Navigator.pop(context, _selectedInterests);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Interested In'),
        automaticallyImplyLeading: true),
        body: Column(  
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Text('Select all that apply for you', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            Padding(
                padding: const EdgeInsets.only(left: 15, right: 15, top: 15),
                child: Material(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    splashColor: const Color.fromARGB(59, 70, 70, 70),
                    highlightColor: const Color.fromARGB(26, 31, 31, 31),
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
                            'Men',
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
                padding: const EdgeInsets.only(left: 15, right: 15, top: 15),
                child: Material(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    splashColor: const Color.fromARGB(59, 70, 70, 70),
                    highlightColor: const Color.fromARGB(26, 31, 31, 31),
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
                            'Women',
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
                padding: const EdgeInsets.only(left: 15, right: 15, top: 15),
                child: Material(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    splashColor: const Color.fromARGB(59, 70, 70, 70),
                    highlightColor: const Color.fromARGB(26, 31, 31, 31),
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
                            'Everyone',
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
          ]
        )
      ),
    );
  }
}