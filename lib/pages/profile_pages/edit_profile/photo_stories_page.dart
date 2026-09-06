//Photo stories: the caption behind each of the user's photos.
//
//A story belongs TO a photo, so there is no separate list of stories to manage
//and no way to end up with an orphan - the photo set is the list, and each row
//either has a story or invites one. Delete the photo and the story goes with
//it (the backend drops it on the next /photos/sync).
//
//The user may write as many or as few as they like; none is a valid state.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/photos_model.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/widgets/pressable.dart';
import 'package:foitifinder/widgets/app_dialog.dart';

class PhotoStoriesPage extends StatefulWidget {
  const PhotoStoriesPage({super.key});

  @override
  State<PhotoStoriesPage> createState() => _PhotoStoriesPageState();
}

class _PhotoStoriesPageState extends State<PhotoStoriesPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  List<PhotosModel> _photos = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      //the photo rows carry their stories, so one call populates the page.
      //getPhotos ignores the uid (the backend takes the owner from the verified
      //ID token) but the signature still wants it.
      final photos = await ApiService.getPhotos(
        FirebaseAuth.instance.currentUser!.uid,
      );
      if (!mounted) return;
      setState(() {
        _photos = photos;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  //Write or clear one photo's story.
  //
  //Saved immediately rather than batched behind a Save button: each story is
  //independent, and a half-finished set should not be lost because the user
  //backed out of the page.
  Future<void> _editStory(PhotosModel photo) async {
    final controller = TextEditingController(text: photo.story ?? '');
    final hadStory = (photo.story ?? '').isNotEmpty;

    final result = await showAppDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(hadStory ? text.editStory : text.addStory),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: text.storyHint),
        ),
        actions: [
          //only offer removal when there is something to remove
          if (hadStory)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, ''),
              child: Text(
                text.removeStory,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(text.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(text.save),
          ),
        ],
      ),
    );

    //null means dismissed - leave the story alone. '' means cleared.
    if (!mounted || result == null) return;

    final trimmed = result.trim();
    //nothing actually changed -> don't spend a request on it
    if (trimmed == (photo.story ?? '')) return;

    final ok = await ApiService.updatePhotoStory(
      photoUrl: photo.photoUrl,
      story: trimmed,
    );
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.errorOccured),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    //reflect the saved value locally instead of refetching the whole list
    setState(() {
      final i = _photos.indexWhere((p) => p.photoUrl == photo.photoUrl);
      if (i != -1) {
        _photos[i] = PhotosModel(
          userId: photo.userId,
          photoUrl: photo.photoUrl,
          displayOrder: photo.displayOrder,
          story: trimmed.isEmpty ? null : trimmed,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.storySaved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(text.photoStories)),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_failed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(text.errorOccured),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: Text(text.retry)),
          ],
        ),
      );
    }

    if (_photos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(text.noPhotosYet, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 24),
      //one extra leading item for the explanatory line
      itemCount: _photos.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              text.photoStoriesIntro,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        }
        final photo = _photos[index - 1];
        return _StoryRow(photo: photo, onTap: () => _editStory(photo));
      },
    );
  }
}

//One photo with its story beside it.
class _StoryRow extends StatelessWidget {
  final PhotosModel photo;
  final VoidCallback onTap;

  const _StoryRow({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = AppLocalizations.of(context)!;
    final story = photo.story ?? '';
    final hasStory = story.isNotEmpty;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: photo.photoUrl,
                  width: 64,
                  height: 84,
                  fit: BoxFit.cover,
                  //a sized placeholder, not a spinner: the row must not change
                  //height when the image lands, or the whole list jumps
                  placeholder: (_, _) => Container(
                    width: 64,
                    height: 84,
                    color: theme.colorScheme.surfaceContainerHigh,
                  ),
                  errorWidget: (_, _, _) => Container(
                    width: 64,
                    height: 84,
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: const Icon(Icons.broken_image_outlined, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasStory ? story : text.addStory,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: hasStory
                      ? theme.textTheme.bodyMedium
                      : theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                hasStory ? Icons.edit_outlined : Icons.add,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
