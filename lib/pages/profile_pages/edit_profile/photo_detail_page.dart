//One photo, big, with the two things you can do to it: replace it, and write
//the story behind it.
//
//Opened by tapping a photo in the edit profile grid. The grid tile is small
//and doubles as a drag handle, so the actions live here instead of as more
//badges crowding a 100px tile.
//
//THE PROFILE PICTURE HAS NO STORY. It is the photo people see next to a name
//in the feed and in matches, where there is nowhere to show a caption, so the
//story button is absent for slot 0 - see [allowStory].
//
//Pops with the newly picked File when the photo was replaced, or null when it
//was not. The caller owns the photo list, so saving stays where the rest of
//the photo saving already is.
//
//The story, unlike the photo, is saved HERE and immediately: it is one field
//on a row that already exists in the backend, so there is nothing to batch.
//
//THE OPENING ANIMATION is two things at once, like Breeze's:
//  * the photo itself flies out of its grid tile, growing and moving to the
//    centre - a Hero, matched to the tile by [heroTag]
//  * everything else (app bar, story, buttons) slides in from the right
//
//That is why this route does NOT slide the whole page. A Hero works out where
//it is flying to from the destination's real position, so sliding the page
//would move the target out from under it. Instead the page stays put, the
//photo is left out of the slide, and only the rest of the content moves.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/photos_model.dart';
import 'package:foitifinder/pages/profile_pages/edit_profile/story_dialog.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/widgets/primary_button.dart';
import 'package:image_picker/image_picker.dart';

//How the page is opened. Kept next to the page so the animation and the
//layout it depends on stay together.
Route<File> photoDetailRoute({
  required File file,
  required String? photoUrl,
  required bool allowStory,
  required Object heroTag,
}) {
  return PageRouteBuilder<File>(
    //long enough to watch the photo travel, short enough not to be in the way
    transitionDuration: const Duration(milliseconds: 360),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => PhotoDetailPage(
      file: file,
      photoUrl: photoUrl,
      allowStory: allowStory,
      heroTag: heroTag,
    ),
    //no transform on the page: the Hero needs its destination to sit still.
    //The background fades so the grid does not simply vanish under it.
    transitionsBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
      child: child,
    ),
  );
}

//shared with the grid tile, so the Hero flight keeps its shape
const double _kPhotoAspect = 3 / 4;
const double _kPhotoRadius = 16;

class PhotoDetailPage extends StatefulWidget {
  //the local copy shown on screen
  final File file;
  //the backend URL, null while the photo has never been saved. A story can
  //only be attached to a photo the backend knows about.
  final String? photoUrl;
  //false for the profile picture
  final bool allowStory;
  //matches the grid tile this photo flew out of
  final Object heroTag;

  const PhotoDetailPage({
    super.key,
    required this.file,
    required this.photoUrl,
    required this.allowStory,
    required this.heroTag,
  });

  @override
  State<PhotoDetailPage> createState() => _PhotoDetailPageState();
}

class _PhotoDetailPageState extends State<PhotoDetailPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  final ImagePicker _picker = ImagePicker();

  String? _story;
  //the story is fetched on open, so the button can say add or edit
  bool _loadingStory = false;

  @override
  void initState() {
    super.initState();
    if (widget.allowStory && widget.photoUrl != null) _loadStory();
  }

  //One call for the whole photo set, then pick ours out of it: there is no
  //endpoint for a single photo, and adding one for a caption is not worth it.
  Future<void> _loadStory() async {
    setState(() => _loadingStory = true);
    try {
      final photos = await ApiService.getPhotos('');
      if (!mounted) return;
      final PhotosModel? mine = photos
          .where((p) => p.photoUrl == widget.photoUrl)
          .firstOrNull;
      setState(() {
        _story = mine?.story;
        _loadingStory = false;
      });
    } catch (_) {
      //the story just stays unknown; the button still works and the dialog
      //opens empty
      if (mounted) setState(() => _loadingStory = false);
    }
  }

  //Replace the photo. Pops straight back with the new file so the grid, which
  //owns the photo list, updates and saves it the usual way.
  Future<void> _changePhoto() async {
    final XFile? image;
    try {
      image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        imageQuality: 85,
      );
    } catch (_) {
      //picker can throw (e.g. denied gallery permission)
      if (mounted) _showError();
      return;
    }
    if (image == null) return; //cancelled

    const List<String> allowedFormats = ['jpg', 'jpeg', 'png'];
    if (!allowedFormats.contains(image.path.split('.').last.toLowerCase())) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text.unsupportedFileType)));
      }
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, File(image.path));
  }

  Future<void> _editStory() async {
    final url = widget.photoUrl;
    //a photo that has never been saved has no row to hang a story on. The grid
    //flushes pending photos before opening this page, so this is only reachable
    //if that save failed.
    if (url == null) {
      _showError();
      return;
    }

    final result = await showStoryDialog(context, initialStory: _story);
    //null means dismissed - leave it alone. '' means cleared.
    if (!mounted || result == null) return;

    final trimmed = result.trim();
    //nothing actually changed -> don't spend a request on it
    if (trimmed == (_story ?? '')) return;

    final ok = await ApiService.updatePhotoStory(photoUrl: url, story: trimmed);
    if (!mounted) return;

    if (!ok) {
      _showError();
      return;
    }

    setState(() => _story = trimmed.isEmpty ? null : trimmed);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.storySaved)));
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.errorOccured), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasStory = (_story ?? '').isNotEmpty;

    //everything except the photo comes in from the right
    final Animation<double> routeAnimation =
        ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    final Animation<Offset> slideIn =
        Tween<Offset>(begin: const Offset(0.4, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: routeAnimation, curve: Curves.easeOutCubic),
        );

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: SlideTransition(
          position: slideIn,
          child: AppBar(
            title: Text(widget.allowStory ? text.photo : text.profilePicture),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Hero(
                    tag: widget.heroTag,
                    child: AspectRatio(
                      //the same 3:4 as the grid tile, so the photo grows
                      //without distorting on the way
                      aspectRatio: _kPhotoAspect,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_kPhotoRadius),
                        //cover, not contain: with contain the image stops
                        //short of the rounded corners and they never show
                        child: Image.file(widget.file, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            //the story, under the photo, so the page shows what is currently
            //written rather than hiding it behind the button
            SlideTransition(
              position: slideIn,
              child: Column(
                children: [
                  if (widget.allowStory)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _loadingStory
                            ? ''
                            : hasStory
                            ? _story!
                            : text.storyHint,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: hasStory
                            ? theme.textTheme.bodyMedium
                            : theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        text.profilePictureNoStory,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: PrimaryButton(
                      label: text.changePhoto,
                      onPressed: _changePhoto,
                    ),
                  ),
                  if (widget.allowStory)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: TextButton(
                        onPressed: _editStory,
                        child: Text(hasStory ? text.editStory : text.addStory),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
