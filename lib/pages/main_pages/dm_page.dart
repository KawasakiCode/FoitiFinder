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
  //list that grabs all the users dms from the db
  List<MatchModel> _dms = [];
  //list that grabs all the matches the user hasnt interacted with yet
  List<MatchModel> _newMatches = [];
  //list that contains all the dms that are results of the searchbar 
  List<MatchModel> _filteredDms = [];

  @override
  void initState() {
    super.initState();
    _loadDMs();
  }

  Future<void> _loadDMs() async {
    final dms = await ApiService.getMatches(
      uid: FirebaseAuth.instance.currentUser!.uid,
    );
    final newMatches = await ApiService.getNewMatches(
      FirebaseAuth.instance.currentUser!.uid,
    );
    if (mounted) {
      setState(() {
        _dms = dms;
        _newMatches = newMatches;
        _filteredDms = dms;
      });
    }
  }
  
  //search filter function
  void _runFilter(String query) {
    final results = query.isEmpty 
      ? _dms
      : _dms.where((match) {
        final name = match.userBname.toLowerCase();
        final input = query.toLowerCase();
        return name.contains(input);
      }).toList();
    
    setState(() {
      _filteredDms = results;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    if (text == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
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
                      onChanged: (value) => _runFilter(value),
                    ),
                  ),
                ],
              ),
            ),
            if (_newMatches.isNotEmpty) ...[
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
                  itemCount: _newMatches.length,
                  itemBuilder: (context, index) {
                    return Material(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.transparent,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () async {
                          await ApiService.updateMatchSeen(
                            _newMatches[index].matchId,
                            FirebaseAuth.instance.currentUser!.uid,
                          );
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MessagesPage(match: _dms[index]),
                            ),
                          );
                        },
                        child: SizedBox(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 18),
                            child: Hero(
                              tag: _newMatches[index].matchId,
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color.fromARGB(
                                  255,
                                  255,
                                  255,
                                  255,
                                ),
                                child: ClipOval(
                                  child: _newMatches[index].imageUrl != null
                                      ? Image.network(
                                          _newMatches[index].imageUrl!,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          alignment: Alignment.topCenter,
                                        )
                                      : Image.asset(
                                          'assets/images/default_avatar.png',
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else ... [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 5, 15, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      text.noMatches,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
            if (_dms.isNotEmpty) ...[
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
                  itemCount: _filteredDms.length,
                  itemBuilder: (context, index) {
                    final dm = _filteredDms[index];
        
                    return Material(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.transparent,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () async {
                          await ApiService.updateMatchSeen(
                            _filteredDms[index].matchId,
                            FirebaseAuth.instance.currentUser!.uid,
                          );
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MessagesPage(match: dm),
                            ),
                          );
                        },
                        child: SizedBox(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 10, 15, 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Hero(
                                  tag: dm.matchId + 1,
                                  child: CircleAvatar(
                                    radius: 28,
                                    backgroundColor: const Color.fromARGB(
                                      255,
                                      255,
                                      255,
                                      255,
                                    ),
                                    backgroundImage: dm.imageUrl != null
                                        ? NetworkImage(dm.imageUrl!)
                                        : const AssetImage(
                                            'assets/images/default_avatar.png',
                                          ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      0,
                                      0,
                                      0,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
            ] else ... [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 5, 15, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      text.noMessages,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
