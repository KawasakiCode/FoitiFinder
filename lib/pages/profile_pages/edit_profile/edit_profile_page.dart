//Edit profile page: what other people see - photos, stories, tags, choices.
//
//Photos save when the page closes (they are uploaded as a batch). Everything
//else SAVES THE MOMENT ITS DIALOG OR PAGE RETURNS, through PATCH /users/me:
//the row updates at once and reverts with a snackbar if the backend refuses
//(saveProfileField). Nothing is held in this page's state, so the rows always
//show what ProfileProvider - and therefore the database - has.

import 'dart:io';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foitifinder/constants/interest_catalogue.dart';
import 'package:foitifinder/constants/profile_options.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/l10n/catalogue_labels.dart';
import 'package:foitifinder/pages/profile_pages/shared/choice_dialog.dart';
import 'package:foitifinder/pages/profile_pages/shared/choice_page.dart';
import 'package:foitifinder/pages/profile_pages/shared/coming_soon_page.dart';
import 'package:foitifinder/pages/profile_pages/shared/save_profile_field.dart';
import 'package:foitifinder/pages/profile_pages/edit_profile/personality/bio_page.dart';
import 'package:foitifinder/pages/profile_pages/edit_profile/photo_detail_page.dart';
import 'package:foitifinder/pages/profile_pages/edit_profile/photo_stories_page.dart';
import 'package:foitifinder/pages/profile_pages/edit_profile/personality/interest_group_page.dart';
import 'package:foitifinder/pages/profile_pages/edit_profile/personality/placeholder_group_page.dart';
import 'package:foitifinder/theme/app_colors.dart';
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

  //---------------------------- drag to reorder ----------------------------
  //
  //Long press a photo, drag it, and the others slide out of the way. INSERT,
  //not swap: dropping photo 3 on slot 1 puts it first and pushes 1 and 2 one
  //place right. Slot 0 is the profile picture, so dragging a photo there is how
  //the picture is changed without a new upload.
  //
  //Nothing is saved during the drag. The drop reorders _photos and sets
  //_photosChanged, and the normal save on leaving the page syncs the list -
  //display_order is just each URL's position in it, and stories follow their
  //photo because the backend matches them by URL.
  static const int _gridColumns = 3;
  static const double _gridSpacing = 8;
  //width / height of a tile
  static const double _tileAspect = 0.75;
  static const Duration _reflowDuration = Duration(milliseconds: 220);

  //index in _photos of the photo being dragged, null when not dragging
  int? _dragFrom;
  //the slot it would land in if dropped now
  int? _dragTo;
  //how far the finger has moved since the long press fired
  Offset _dragOffset = Offset.zero;
  //the photo dragged last. Drawn on top of the others, so after the drop it
  //glides home OVER its neighbours instead of dipping under them.
  _PhotoSlot? _lastDragged;
  //true while existing photos are still downloading into their slots by
  //index. Reordering then would have them land in the wrong places.
  bool _photosLoading = false;

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
      send: (_) =>
          ApiService.patchUser({choice.key: choiceToJson(choice, picks)}),
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

  //Tapping a photo opens it full size, where it can be replaced and (unless it
  //is the profile picture) given a story.
  //
  //Pending photo changes are flushed FIRST, for the same reason the stories
  //page does it: a story is saved against a photo URL, so the photo has to
  //exist in the backend before one can be written.
  Future<void> _openPhoto(int index) async {
    final slot = _photos[index];
    //an empty slot has nothing to show - go straight to the picker
    if (slot == null) {
      _pickImage(index);
      return;
    }

    if (_photosChanged) {
      try {
        await _submitPhotos();
      } catch (_) {
        //_submitPhotos already told the user; the page below still opens, just
        //without the story option on an unsaved photo
      }
      if (!mounted) return;
    }

    final current = _photos[index];
    if (current == null) return;

    final replacement = await Navigator.push<File>(
      context,
      photoDetailRoute(
        file: current.file,
        photoUrl: current.existingUrl,
        //slot 0 is the profile picture
        allowStory: index != 0,
        heroTag: _photoHeroTag(index),
      ),
    );
    if (!mounted || replacement == null) return;

    setState(() {
      _photos[index] = _PhotoSlot(replacement);
      _photosChanged = true;
    });
  }

  //The photo flies from this tile to the middle of the detail page. Keyed by
  //SLOT, not by the file: duplicates are allowed in the grid, and two Heroes
  //sharing a tag is a crash.
  Object _photoHeroTag(int index) => 'photo-slot-$index';

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
    //plain assignment: this runs from initState, where setState is not allowed
    //and the first build reads the flag anyway
    _photosLoading = true;
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
            _photos[i] = _PhotoSlot(
              file,
              existingUrl: backendPhotos[i].photoUrl,
            );
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
    } finally {
      if (mounted) setState(() => _photosLoading = false);
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

      //Drop any failed upload (null) so we never sync a broken URL, and pair
      //each surviving slot with the URL it now lives at.
      final List<_PhotoSlot> savedSlots = [];
      final List<String> photoUrls = [];
      for (var i = 0; i < orderedSlots.length; i++) {
        final url = resolvedUrls[i];
        if (url == null) continue;
        savedSlots.add(_PhotoSlot(orderedSlots[i].file, existingUrl: url));
        photoUrls.add(url);
      }

      //Safety: the user always keeps at least one photo, so an empty result can
      //only mean every upload failed. Abort rather than wiping their photos.
      if (photoUrls.isEmpty) {
        throw Exception('All photo uploads failed');
      }

      //Reconcile the backend to exactly this ordered list: keeps unchanged
      //photos, inserts new ones, deletes removed ones — no duplicates.
      //syncPhotos reports failure by returning false, not by throwing - it
      //was being ignored, so a failed save looked like a successful one
      final synced = await ApiService.syncPhotos(
        uid: uid,
        photoUrls: photoUrls,
      );
      if (!synced) throw Exception('Photo sync failed');
      //the sync also sets has_photos on the backend

      //photo 0 is the profile picture, so this is also what updates the
      //avatar on the profile page
      if (mounted) {
        Provider.of<ProfileProvider>(
          context,
          listen: false,
        ).setPhotoUrls(photoUrls);
      }

      //The slots now match what the backend holds: each carries its URL, so a
      //later save re-uploads nothing, and a story can be attached to a photo
      //that was picked a moment ago. Without this every slot stayed "new" and
      //the next save uploaded the whole set again under fresh URLs, taking
      //their stories with it.
      if (mounted) {
        setState(() {
          for (var i = 0; i < _photos.length; i++) {
            _photos[i] = i < savedSlots.length ? savedSlots[i] : null;
          }
        });
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
                      child: _buildPhotoGrid(),
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
                        for (final title in const [kGroupHobbies, kGroupTraits])
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
                          onTap: () =>
                              _push(ComingSoonPage(title: text.myTune)),
                        ),
                        NavRow(
                          label: text.favouriteArtists,
                          onTap: () => _push(
                            ComingSoonPage(title: text.favouriteArtists),
                          ),
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
                          onTap: () => _push(
                            ComingSoonPage(
                              title: catalogueLabel(
                                text,
                                kChoicePronouns.title,
                              ),
                            ),
                          ),
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

  //Where a photo sits on screen right now: its own slot, or - mid drag - the
  //slot it has been pushed into to make room. Only the photos BETWEEN the
  //dragged one's origin and its target move, each by one place.
  int _previewIndex(int index) {
    final from = _dragFrom;
    final to = _dragTo;
    if (from == null || to == null || index == from) return index;
    //dragged forwards: everything it passed shifts back one
    if (from < to && index > from && index <= to) return index - 1;
    //dragged backwards: everything it passed shifts forward one
    if (from > to && index >= to && index < from) return index + 1;
    return index;
  }

  //top-left corner of a slot inside the grid
  Offset _cellOrigin(int index, Size cell) => Offset(
    (index % _gridColumns) * (cell.width + _gridSpacing),
    (index ~/ _gridColumns) * (cell.height + _gridSpacing),
  );

  //The slot the dragged tile is MORE THAN HALF over, judged by its centre:
  //once the centre crosses the gap into a neighbour, at least half the tile
  //is on top of it. Rows work the same way, so dragging up from the second
  //row into the first flips at the halfway point too.
  //
  //Clamped to the filled slots - a photo dropped over an empty slot goes to
  //the end of the photos, never leaving a gap before it.
  int _slotUnder(Offset center, Size cell, int filledCount) {
    final rows = _photos.length ~/ _gridColumns;
    final col = ((center.dx + _gridSpacing / 2) / (cell.width + _gridSpacing))
        .floor()
        .clamp(0, _gridColumns - 1);
    final row = ((center.dy + _gridSpacing / 2) / (cell.height + _gridSpacing))
        .floor()
        .clamp(0, rows - 1);
    return (row * _gridColumns + col).clamp(0, filledCount - 1);
  }

  void _onDragStart(int index) {
    if (_photosLoading || _isLoading) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _dragFrom = index;
      _dragTo = index;
      _dragOffset = Offset.zero;
      _lastDragged = _photos[index];
    });
  }

  void _onDragUpdate(Offset offsetFromOrigin, Size cell) {
    final from = _dragFrom;
    if (from == null) return;
    final center =
        _cellOrigin(from, cell) +
        Offset(cell.width / 2, cell.height / 2) +
        offsetFromOrigin;
    final to = _slotUnder(center, cell, _photos.whereType<_PhotoSlot>().length);
    //a tick each time the others rearrange, so the reflow is felt too
    if (to != _dragTo) HapticFeedback.selectionClick();
    setState(() {
      _dragOffset = offsetFromOrigin;
      _dragTo = to;
    });
  }

  void _onDragEnd() {
    final from = _dragFrom;
    final to = _dragTo;
    if (from == null || to == null) return;
    setState(() {
      if (from != to) {
        final filled = _photos.whereType<_PhotoSlot>().toList();
        filled.insert(to, filled.removeAt(from));
        for (var i = 0; i < _photos.length; i++) {
          _photos[i] = i < filled.length ? filled[i] : null;
        }
        _photosChanged = true;
      }
      _dragFrom = null;
      _dragTo = null;
      _dragOffset = Offset.zero;
    });
  }

  //The grid. A Stack of absolutely positioned tiles rather than a GridView,
  //because a GridView lays its children out itself and cannot animate them
  //sliding between cells.
  //
  //Every photo is an AnimatedPositioned keyed by the photo itself, so when
  //its slot changes Flutter keeps the same widget and animates it to the new
  //place instead of redrawing a different image there. The dragged tile has a
  //zero duration while held, so it tracks the finger exactly, and gets the
  //normal duration back on release, which is what makes it glide into the
  //slot it was dropped on.
  Widget _buildPhotoGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth - _gridSpacing * (_gridColumns - 1)) /
            _gridColumns;
        final cell = Size(cellWidth, cellWidth / _tileAspect);
        final rows = _photos.length ~/ _gridColumns;
        final filledCount = _photos.whereType<_PhotoSlot>().length;
        final dragging = _dragFrom != null;

        final children = <Widget>[];

        //empty slots never move: they are always the ones after the photos
        for (var i = filledCount; i < _photos.length; i++) {
          final origin = _cellOrigin(i, cell);
          children.add(
            Positioned(
              key: ValueKey('empty-$i'),
              left: origin.dx,
              top: origin.dy,
              width: cell.width,
              height: cell.height,
              child: _buildPhotoSlot(i),
            ),
          );
        }

        //photos, with the one being (or last) dragged added last so it draws
        //above the rest
        final order = [
          for (var i = 0; i < filledCount; i++)
            if (!identical(_photos[i], _lastDragged)) i,
          for (var i = 0; i < filledCount; i++)
            if (identical(_photos[i], _lastDragged)) i,
        ];

        for (final i in order) {
          final isDragged = i == _dragFrom;
          final origin = isDragged
              ? _cellOrigin(i, cell) + _dragOffset
              : _cellOrigin(_previewIndex(i), cell);

          children.add(
            AnimatedPositioned(
              key: ObjectKey(_photos[i]),
              duration: isDragged ? Duration.zero : _reflowDuration,
              curve: Curves.easeOutCubic,
              left: origin.dx,
              top: origin.dy,
              width: cell.width,
              height: cell.height,
              child: GestureDetector(
                //long press, so a tap still opens the picker and a quick
                //swipe still scrolls the page
                onLongPressStart: (_) => _onDragStart(i),
                onLongPressMoveUpdate: (details) =>
                    _onDragUpdate(details.offsetFromOrigin, cell),
                onLongPressEnd: (_) => _onDragEnd(),
                //shakes while held, otherwise looks exactly as at rest
                child: _Wiggle(
                  active: isDragged,
                  //the pencil/X belong to a slot, not a photo: hidden while
                  //the photos are in flux, back on the drop
                  child: _buildPhotoSlot(i, showBadges: !dragging),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: rows * cell.height + (rows - 1) * _gridSpacing,
          child: Stack(
            //the badges overhang the tile edges
            clipBehavior: Clip.none,
            children: children,
          ),
        );
      },
    );
  }

  //build the actual photo slot that goes inside the grid
  Widget _buildPhotoSlot(int index, {bool showBadges = true}) {
    final photo = _photos[index];

    return Stack(
      clipBehavior:
          Clip.none, // Allows the button to slightly overhang the edge
      children: [
        // 1. The Main Photo Slot
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _openPhoto(index),
            child: Container(
              decoration: BoxDecoration(
                //TRANSPARENT UNDER A PHOTO. While the photo is flying to the
                //detail page the Hero leaves an empty placeholder here, and a
                //filled box made that read as a white hole punched in the
                //grid. Transparent means the page background shows through,
                //so the slot looks like it travelled with the photo.
                //
                //Empty slots keep a fill, since that box IS the "add a photo"
                //target. Theme colours, not Colors.grey[200], which was a
                //light-grey box in dark mode too.
                color: photo != null
                    ? Colors.transparent
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: photo != null
                  ? Hero(
                      tag: _photoHeroTag(index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(photo.file, fit: BoxFit.cover),
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.add,
                        size: 30,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ),

        // 2. Slot 0 is the profile picture: it can be REPLACED, never removed.
        // It is the one photo every account must have, so it gets a pencil
        // instead of an X. This is also what guarantees the user always keeps
        // at least one photo - removing any other slot can't reach zero.
        if (showBadges && photo != null && index == 0)
          _PhotoCornerButton(icon: Icons.edit, onTap: () => _pickImage(0)),

        // 3. The remove button, on every other photo
        if (showBadges && photo != null && index != 0)
          _PhotoCornerButton(
            icon: Icons.close,
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
          ),
      ],
    );
  }
}

//The small button in a photo's top-right corner: the pencil on the profile
//picture, the X on every other photo. One widget so the two can never drift
//apart in size, colour or placement.
//
//INSIDE the photo, inset from its top and right edges, rather than hanging
//off the corner - an overhanging badge got clipped by neighbouring tiles
//during the reorder animation and looked detached from its photo.
class _PhotoCornerButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PhotoCornerButton({required this.icon, required this.onTap});

  //gap between the button and the photo's top and right edges
  static const double _inset = 6;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _inset,
      right: _inset,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            //deeper and quieter than the bright primary, so the button sits on
            //the photo instead of shouting over it
            color: AppColors.primaryDeep,
            //a rounded square, not a circle: reads as a button rather than a
            //notification dot
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: AppColors.onPrimary, size: 15),
        ),
      ),
    );
  }
}

//Shakes its child left and right for as long as [active] is true - the "I am
//being moved" signal on a held photo. Nothing else about the photo changes:
//same size, same opacity.
//
//The controller only runs while active, so a grid of idle photos costs no
//frames.
class _Wiggle extends StatefulWidget {
  final bool active;
  final Widget child;

  const _Wiggle({required this.active, required this.child});

  @override
  State<_Wiggle> createState() => _WiggleState();
}

class _WiggleState extends State<_Wiggle> with SingleTickerProviderStateMixin {
  //one full left-right-left cycle. Fast enough to read as a vibration rather
  //than as the photo swaying.
  static const Duration _period = Duration(milliseconds: 260);
  //how far it travels each way, in logical pixels
  static const double _amplitude = 2;
  //and how far it tilts each way, in radians (about 1.5 degrees)
  static const double _tilt = 0.026;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(_Wiggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      //settle back to rest instead of freezing mid-tilt
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        //a sine wave, so it eases through each end instead of bouncing off it
        final wave = math.sin(_controller.value * 2 * math.pi);
        return Transform.translate(
          offset: Offset(wave * _amplitude, 0),
          child: Transform.rotate(angle: wave * _tilt, child: child),
        );
      },
    );
  }
}

//A photo shown in the edit grid: either one already saved on the backend
//(existingUrl != null, so it never needs re-uploading) or a freshly-picked
//local file that still has to be uploaded on save.
class _PhotoSlot {
  final File
  file; // local file used for display (a downloaded copy for existing)
  final String? existingUrl; // backend URL if already saved; null = new pick
  const _PhotoSlot(this.file, {this.existingUrl});
  bool get isNew => existingUrl == null;
}
