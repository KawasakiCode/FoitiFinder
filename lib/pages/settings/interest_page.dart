import 'package:flutter/material.dart';

Set<String> _selectedInterests = {};

class InterestPage extends StatefulWidget {
  final Set<String> initialSelection;

  const InterestPage({super.key, required this.initialSelection});

  @override
  State<InterestPage> createState() => _InterestPageState();
}

class _InterestPageState extends State<InterestPage> {
  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  } 

  @override
  void initState() {
    super.initState();
    _selectedInterests = Set.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext buildContext) {
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
                    onTap: () => _toggleInterest("Men"),
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
                          if (_selectedInterests.contains("Men"))
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
                    onTap: () => _toggleInterest("Women"),
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
                          if (_selectedInterests.contains("Women"))
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
                    onTap: () => _toggleInterest("Everyone"),
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
                          if (_selectedInterests.contains("Everyone"))
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