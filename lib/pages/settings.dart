import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  RangeValues _values = RangeValues(20, 80);
  bool enabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings'), automaticallyImplyLeading: true),
      body: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 15, top: 10),
              child: Text(
                'Account Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
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
                onTap: () {
                  // TODO: handle phone number tap
                },
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 8,
                    bottom: 8,
                    left: 10,
                    right: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Phone Number',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '3069xxxxxxxx',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 15, top: 10),
              child: Text(
                'Discovery Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
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
                onTap: () {
                  // TODO: handle interested-in tap
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, left: 10, right: 10, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interested In',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'dynamically added text here',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Image.asset(
                            'assets/icons/right-arrow.png',
                            width: 10,
                            height: 10,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 15, right: 15, top: 20),
            child: Container(  
              padding: const EdgeInsets.only(left: 15, right: 15, top: 10, bottom: 10),
              decoration: BoxDecoration( 
                border: Border.all(color: Colors.grey, width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(  
                children: [
                  Row(  
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Age Range', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      Text('dynamic text here', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500))
                    ]
                  ),
                  RangeSlider(  
                    values: _values, 
                    min: 18,
                    max: 100,
                    divisions: 82,
                    onChanged: (v) => setState(() => _values = v),
                  ),
                  Row(  
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(  
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Show people out of range if', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                          Text('I run out of profiles to see', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        ]
                      ),
                      Transform.scale(
                        scale: 1,
                        child: Switch(  
                          value: enabled,
                          onChanged: (v) => setState(() => enabled = v),
                        ),
                      )
                    ]
                  )
                ]
              )
            ),
          )
        ],
      ),
    );
  }
}
