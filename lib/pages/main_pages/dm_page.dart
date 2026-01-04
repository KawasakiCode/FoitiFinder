import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/matches_model.dart';
import 'package:foitifinder/pages/extra_pages/messages_page.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:provider/provider.dart';

class DMPage extends StatefulWidget {
  const DMPage({super.key});

  @override
  State<DMPage> createState() => _DMPageState();
}

class _DMPageState extends State<DMPage> {
  List<MatchModel> _dms = [];

  @override
  void initState() {
    super.initState();
    _loadDMs();
  }

  Future<void> _loadDMs() async {
    final dms = await ApiService.getMatches(uid: FirebaseAuth.instance.currentUser!.uid);

    if(mounted) {
      setState(() => _dms = dms);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final user = Provider.of<ProfileProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.currentUser!.username,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 15, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SearchBar(
                    constraints: BoxConstraints(maxHeight: 40, minHeight: 40),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    leading: Image.asset(
                      'assets/icons/search.png',
                      width: 17,
                      height: 17,
                      key: UniqueKey(),
                    ),
                    hintText: text.search,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 5, 15, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  text.newMatches,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            margin: EdgeInsets.all(0),
            width: MediaQuery.of(context).size.width,
            height: 85,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 10,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5.0),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 5, 15, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  text.messages,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.vertical,
              itemCount: _dms.length,
              itemBuilder: (context, index) {
                final dm = _dms[index];

                return Material(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () {
                      Navigator.push(  
                        context,
                        MaterialPageRoute(builder:(context) => MessagesPage(),),
                      );
                    },
                    child: SizedBox(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 15, 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Hero(
                              tag: dm.matchId,
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: NetworkImage(dm.imageUrl),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dm.userBname,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Last Message',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
