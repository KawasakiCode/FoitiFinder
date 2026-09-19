//Edit profile page: what other people see - photos, stories, tags, choices.
//
//Photos save when the page closes (they are uploaded as a batch). Everything
//else SAVES THE MOMENT ITS DIALOG OR PAGE RETURNS, through PATCH /users/me:
//the row updates at once and reverts with a snackbar if the backend refuses
//(saveProfileField). Nothing is held in this page's state, so the rows always
//show what ProfileProvider - and therefore the database - has.

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/constants/interest_catalogue.dart';
import 'package:foitifinder/constants/profile_options.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/l10n/catalogue_labels.dart';
import 'package:foitifinder/pages/profile_pages/shared/choice_dialog.dart';
import 'package:foitifinder/pages/profile_pages/shared/choice_page.dart';
import 'package:foitifinder/pages/profile_pages/shared/coming_soon_page.dart';
import 'package:foitifinder/pages/profile_pages/shared/save_profile_field.dart';
import 'package:foitifinder/pages/profile_pages/edit_profile/personality/bio_page.dart';
import 'package:foitifinder/pages/profile_pages/edit_profile/photo_stories_page.dart';
import 'package:foitifinder/pages/profile_pages/edit_profile/personality/interest_group_page.dart';
import 'package:foitifinder/pages/profile_pages/edit_profile/personality/placeholder_group_page.dart';
import 'package:foitifinder/widgets/nav_row.dart';
import 'package:foitifinder/models/photos_model.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/widgets/loading_overlay.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  bool _allowExit = false;

  //allow up to 6 photos
  //duplicates allowed
  final List<_PhotoSlot?> _photos = List.filled(6, null);
  //true once the user actually adds/removes a photo — so we only re-upload &
  //re-score when the photo set really changed, never on a plain profile edit.
  bool _photosChanged = false;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;

  //the signed-in user, read fresh each time so a save that just landed (or
  //was reverted) is what the rows show
  UserModel get _user =>
      Provider.of<ProfileProvider>(context, listen: false).currentUser!;

  List<String> _tagsFor(String groupTitle) =>
      kGroupColumns[groupTitle] == 'trait_tags'
          ? _user.traitTags
          : _user.interestTags;

  int _pickCount(String groupTitle) => _tagsFor(groupTitle).length;

  //what a row shows on the right: the answer itself when there is one, a count
  //when there are several, nothing when empty
  String _choiceSummary(ProfileChoice choice) {
    final picks = _user.choice(choice.key);
    if (picks.isEmpty) return '';
    if (picks.length == 1) return catalogueLabel(text, picks.first);
    return '${picks.length}';
  }

  //Save one choice answer. Skipped when nothing changed, so opening a dialog
  //and closing it again never reaches the backend.
  Future<void> _saveChoice(ProfileChoice choice, List<String> picks) async {
    if (listEquals(picks, _user.choice(choice.key))) return;
    await saveProfileField<List<String>>(
      context,
      read: (u) => u.choice(choice.key),
      write: (u, value) => u.withChoice(choice.key, value),
      value: picks,
      send: (_) => ApiService.patchUser({
        choice.key: choiceToJson(choice, picks),
      }),
    );
  }

  //Stories attach to photos that must already exist in the backend, so flush
  //any unsaved photo changes first. Opening the page with a photo the server
  //has never seen would show a stale list and save a story against a URL that
  //is about to be replaced.
  Future<void> _openPhotoStories() async {
    if (_photosChanged) {
      await _submitPhotos();
      if (!mounted) return;
    }
    _push(const PhotoStoriesPage());
  }

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  //Open a tag group (Hobbies & interests, Traits), or the page that stands in
  //for the groups with no mechanic yet.
  Future<void> _openGroup(String groupTitle) async {
    final group = interestGroupByTitle(groupTitle);

    if (groupTitle == kGroupBio) {
      _push(const BioPage());
      return;
    }
    if (group.sections.isEmpty) {
      _push(PlaceholderGroupPage(group: group));
      return;
    }

    final column = kGroupColumns[groupTitle]!;
    final current = _tagsFor(groupTitle);

    final result = await Navigator.push<Map<String, List<String>>>(
      context,
      MaterialPageRoute(
        builder: (_) => InterestGroupPage(
          group: group,
          //the database has a flat list; the page wants it per section
          initialSelections: selectionsFromTags(group, current),
        ),
      ),
    );
    if (!mounted || result == null) return;

    final tags = tagsFromSelections(group, result);
    if (listEquals(tags, current)) return;

    await saveProfileField<List<String>>(
      context,
      read: (u) => column == 'trait_tags' ? u.traitTags : u.interestTags,
      write: (u, value) => column == 'trait_tags'
          ? u.copyWith(traitTags: value)
          : u.copyWith(interestTags: value),
      value: tags,
      send: (_) => ApiService.patchUser({column: tags}),
    );
  }

  //Long lists (religion, political view) get a full page; a dialog would
  //scroll and feel worse than a push.
  Future<void> _openChoicePage(ProfileChoice choice) async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ChoicePage(
          choice: choice,
          initialSelected: _user.choice(choice.key),
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _saveChoice(choice, result);
  }

  //Short lists (alcohol, smoking, dating intention, kids) answer in one tap,
  //so they open a dialog instead of pushing a whole screen.
  Future<void> _openChoiceDialog(ProfileChoice choice) async {
    final result = await showChoiceDialog(
      context,
      choice: choice,
      initialSelected: _user.choice(choice.key),
    );
    //null means dismissed - leave the answer alone. An empty list means cleared.
    if (!mounted || result == null) return;
    await _saveChoice(choice, result);
  }

  @override
  //grab existing data from firebase and provider(database)
  void initState() {
    super.initState();
    final user = Provider.of<ProfileProvider>(
      context,
      listen: false,
    ).currentUser!;

    if (user.hasPhotos) {
      _getUserPhotos();
    }
  }

  Future<void> _getUserPhotos() async {
    try {
      List<PhotosModel> backendPhotos = await ApiService.getPhotos(
        FirebaseAuth.instance.currentUser!.uid,
      );
      for (int i = 0; i < backendPhotos.length; i++) {
        if (i >= 6) break;
        File file = await urlToFile(backendPhotos[i].photoUrl);

        if (mounted) {
          setState(() {
            //existing photo: remember its backend URL so we never re-upload it
            _photos[i] = _PhotoSlot(file, existingUrl: backendPhotos[i].photoUrl);
          });
        }
      }
    } catch (e) {
      //called fire-and-forget from initState, so surface the error instead of
      //throwing into an unhandled future
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.errorOccured),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  //download and save actual photo file
  Future<File> urlToFile(String imageUrl) async {
    final directory = await getTemporaryDirectory();
    final filename = path.basename(imageUrl);
    final file = File('${directory.path}/$filename');

    if (await file.exists()) {
      return file;
    }
    final response = await http.get(Uri.parse(imageUrl));
    //don't write a failed response (e.g. an error page) as if it were an image
    if (response.statusCode != 200) {
      throw Exception('Failed to download image (${response.statusCode})');
    }

    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  //Save what this page still owns - the photos - and leave.
  //
  //Username, full name and age USED to be edited here and are now on the
  //Account Settings page, so all of their validation and their write went with
  //them. Bio is likewise not saved from here: BioPage writes it directly, and
  //a controller seeded when this page opened would send a stale value back
  //over a newer edit.
  Future<void>? _saveAndExit() async {
    try {
      await _submitPhotos();

      if (mounted) {
        setState(() {
          _allowExit = true;
        });
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allowExit = true;
        });
      }
    }
  }

  //Function to add a photo in the list
  Future<void> _pickImage(int index) async {
    //store the image in smaller resolution to improve loading times
    final XFile? image;
    try {
      image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        imageQuality: 85,
      );
    } catch (e) {
      //picker can throw (e.g. denied gallery permission)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.errorOccured),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    //user cancelled the picker, nothing to do
    if (image == null) return;

    final String extension = image.path.split('.').last.toLowerCase();
    const List<String> allowedFormats = ['jpg', 'jpeg', 'png'];
    if (!allowedFormats.contains(extension)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.unsupportedFileType),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Save the valid photo and compact the grid (no gaps)
    setState(() {
      _photos[index] = _PhotoSlot(File(image!.path)); // new pick, needs upload
      _photosChanged = true;

      List<_PhotoSlot?> validPhotos = _photos
          .where((photo) => photo != null)
          .toList();
      for (int i = 0; i < _photos.length; i++) {
        _photos[i] = i < validPhotos.length ? validPhotos[i] : null;
      }
    });
  }

  Future<void> _submitPhotos() async {
    //Nothing changed in the photo grid — don't re-upload or re-score. This is
    //what stops the old behaviour of duplicating every photo on each save.
    if (!_photosChanged) return;

    setState(() {
      _isLoading = true;
    });

    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      //Final ordered list of slots the user wants to keep.
      final orderedSlots = _photos.whereType<_PhotoSlot>().toList();

      //Upload ONLY the freshly-picked files; existing photos keep their URL, so
      //nothing already saved is re-uploaded. Preserves slot order.
      final List<String?> resolvedUrls = await Future.wait(
        orderedSlots.map((slot) async {
          if (!slot.isNew) return slot.existingUrl; // reuse — no upload
          return await ApiService.uploadToFirebase(slot.file, uid);
        }),
      );

      //Drop any failed upload (null) so we never sync a broken URL.
      final photoUrls = resolvedUrls.whereType<String>().toList();

      //Safety: the user always keeps at least one photo, so an empty result can
      //only mean every upload failed. Abort rather than wiping their photos.
      if (photoUrls.isEmpty) {
        throw Exception('All photo uploads failed');
      }

      //Reconcile the backend to exactly this ordered list: keeps unchanged
      //photos, inserts new ones, deletes removed ones — no duplicates.
      //syncPhotos reports failure by returning false, not by throwing - it
      //was being ignored, so a failed save looked like a successful one
      final synced =
          await ApiService.syncPhotos(uid: uid, photoUrls: photoUrls);
      if (!synced) throw Exception('Photo sync failed');
      //the sync also sets has_photos on the backend

      //photo 0 is the profile picture, so this is also what updates the
      //avatar on the profile page
      if (mounted) {
        Provider.of<ProfileProvider>(context, listen: false)
            .setPhotoUrls(photoUrls);
      }

      _photosChanged = false;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.errorOccured),
          duration: Duration(seconds: 3),
        ),
      );
      rethrow;
    } finally {
      //unlock uploading stream
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    //subscribe, so rows redraw when a save lands or is reverted
    Provider.of<ProfileProvider>(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PopScope(
        canPop: _allowExit,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _saveAndExit();
        },
        child: SafeArea(
          child: LoadingOverlay(
            isLoading: _isLoading,
            child: Scaffold(
              appBar: AppBar(
                title: Text(text.editProfile),
                automaticallyImplyLeading: true,
              ),
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //=========================== PHOTOS ===========================
                    SectionHeader(text.photos),
                    //3 per row, 2 rows. Smaller than before so the whole grid
                    //plus the first section fits above the fold.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: 6,
                        itemBuilder: (context, index) =>
                            _buildPhotoSlot(index),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CardGroup(
                      dividers: true,
                      children: [
                        NavRow(
                          icon: Icons.auto_stories_outlined,
                          label: text.addStoryToPhoto,
                          onTap: _openPhotoStories,
                        ),
                      ],
                    ),

                    //======================= MY PERSONALITY =======================
                    SectionHeader(text.sectionMyPersonality),
                    CardGroup(
                      dividers: true,
                      children: [
                        for (final title in const [
                          kGroupHobbies,
                          kGroupTraits,
                        ])
                          NavRow(
                            label: catalogueLabel(text, title),
                            trailing: _pickCount(title) == 0
                                ? ''
                                : '${_pickCount(title)}',
                            onTap: () => _openGroup(title),
                          ),
                        //Bio saves itself on its own page, so there is nothing
                        //to summarise on the row
                        NavRow(
                          label: catalogueLabel(text, kGroupBio),
                          onTap: () => _openGroup(kGroupBio),
                        ),
                        NavRow(
                          label: catalogueLabel(text, kGroupQA),
                          onTap: () => _openGroup(kGroupQA),
                        ),
                      ],
                    ),

                    //======================= MY MUSIC TASTE =======================
                    SectionHeader(text.sectionMyMusicTaste),
                    CardGroup(
                      dividers: true,
                      children: [
                        //both need the Spotify API, so both are stubs until
                        //that is wired up
                        NavRow(
                          label: text.myTune,
                          onTap: () => _push(ComingSoonPage(title: text.myTune)),
                        ),
                        NavRow(
                          label: text.favouriteArtists,
                          onTap: () =>
                              _push(ComingSoonPage(title: text.favouriteArtists)),
                        ),
                      ],
                    ),

                    //=================== MY BELIEFS AND VALUES ===================
                    SectionHeader(text.sectionMyBeliefs),
                    CardGroup(
                      dividers: true,
                      children: [
                        for (final choice in const [
                          kChoiceReligion,
                          kChoicePoliticalView,
                        ])
                          NavRow(
                            label: catalogueLabel(text, choice.title),
                            trailing: _choiceSummary(choice),
                            //16 and 18 options: too many for a dialog
                            onTap: () => _openChoicePage(choice),
                          ),
                      ],
                    ),

                    //========================= MY HABITS =========================
                    SectionHeader(text.sectionMyHabits),
                    CardGroup(
                      dividers: true,
                      children: [
                        for (final choice in const [
                          kChoiceAlcohol,
                          kChoiceSmoking,
                        ])
                          NavRow(
                            label: catalogueLabel(text, choice.title),
                            trailing: _choiceSummary(choice),
                            onTap: () => _openChoiceDialog(choice),
                          ),
                      ],
                    ),

                    //=============== WHAT I WANT IN MY RELATIONSHIPS ==============
                    SectionHeader(text.sectionMyRelationships),
                    CardGroup(
                      dividers: true,
                      children: [
                        for (final choice in const [
                          kChoiceDatingIntention,
                          kChoiceKids,
                        ])
                          NavRow(
                            label: catalogueLabel(text, choice.title),
                            trailing: _choiceSummary(choice),
                            onTap: () => _openChoiceDialog(choice),
                          ),
                      ],
                    ),

                    //======================= MY BACKGROUND =======================
                    SectionHeader(text.sectionMyBackground),
                    CardGroup(
                      dividers: true,
                      children: [
                        //NOTE: EducationPage and OccupationPage are already
                        //built and working - swapping either stub for the real
                        //page is a one-line change.
                        //
                        //Location is NOT here: where the user lives is one
                        //value, so it gets one home, and that home is the
                        //Place of residence row in Account Settings.
                        NavRow(
                          label: text.education,
                          onTap: () =>
                              _push(ComingSoonPage(title: text.education)),
                        ),
                        NavRow(
                          label: text.occupation,
                          onTap: () =>
                              _push(ComingSoonPage(title: text.occupation)),
                        ),
                      ],
                    ),

                    //========================== WHO I AM ==========================
                    SectionHeader(text.sectionWhoIAm),
                    CardGroup(
                      dividers: true,
                      children: [
                        NavRow(
                          label: catalogueLabel(text, kChoicePronouns.title),
                          onTap: () => _push(ComingSoonPage(
                            title: catalogueLabel(text, kChoicePronouns.title),
                          )),
                        ),
                        NavRow(
                          label: text.languagesSpoken,
                          onTap: () => _push(
                            ComingSoonPage(title: text.languagesSpoken),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  //build the actual photo slot that goes inside the grid builder
  Widget _buildPhotoSlot(int index) {
    final photo = _photos[index];

    return Stack(
      clipBehavior:
          Clip.none, // Allows the button to slightly overhang the edge
      children: [
        // 1. The Main Photo Slot
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _pickImage(index),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: photo != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(photo.file, fit: BoxFit.cover),
                    )
                  : const Center(
                      child: Icon(Icons.add, color: Colors.grey, size: 30),
                    ),
            ),
          ),
        ),

        // 2. Slot 0 is the profile picture: it can be REPLACED, never removed.
        // It is the one photo every account must have, so it gets a pencil
        // instead of an X. This is also what guarantees the user always keeps
        // at least one photo - removing any other slot can't reach zero.
        if (photo != null && index == 0)
          Positioned(
            top: -5,
            left: -5,
            child: GestureDetector(
              onTap: () => _pickImage(0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 16,
                ),
              ),
            ),
          ),

        // 3. The Top-Left Remove Button, on every other photo
        if (photo != null && index != 0)
          Positioned(
            top: -5,
            left: -5,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  // 1. Set the removed photo's slot to null
                  _photos[index] = null;
                  _photosChanged = true;

                  // 2. Gather all the photos that are still left
                  List<_PhotoSlot?> remainingPhotos = _photos
                      .where((photo) => photo != null)
                      .toList();

                  // 3. Re-deal them into the fixed array from left to right
                  for (int i = 0; i < _photos.length; i++) {
                    if (i < remainingPhotos.length) {
                      _photos[i] =
                          remainingPhotos[i]; // Fill with remaining photos
                    } else {
                      _photos[i] = null; // Fill the rest with empty slots
                    }
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }
}

//A photo shown in the edit grid: either one already saved on the backend
//(existingUrl != null, so it never needs re-uploading) or a freshly-picked
//local file that still has to be uploaded on save.
class _PhotoSlot {
  final File file; // local file used for display (a downloaded copy for existing)
  final String? existingUrl; // backend URL if already saved; null = new pick
  const _PhotoSlot(this.file, {this.existingUrl});
  bool get isNew => existingUrl == null;
}
