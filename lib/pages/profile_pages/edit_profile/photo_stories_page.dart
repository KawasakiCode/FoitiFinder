//Photo stories: the caption behind each of the user's photos.
//
//A story belongs TO a photo, so there is no separate list of stories to manage
//and no way to end up with an orphan - the photo set is the list, and each row
//either has a story or invites one. Delete the photo and the story goes with
//it (the backend drops it on the next /photos/sync).
//
//The user may write as many or as few as they like; none is a valid state.
//
//THE PROFILE PICTURE IS NOT IN THIS LIST. Photo 0 is what people see beside a
//name in the feed and in matches, where a caption has nowhere to go, so it is
//filtered out here and refused by the backend - see photo_detail_page.dart.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/photos_model.dart';
import 'package:foitifinder/pages/profile_pages/edit_profile/story_dialog.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/polish.dart';
import 'package:foitifinder/widgets/pressable.dart';

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
  //rows that have already played their entrance; see Entrance.shouldPlay
  final Set<String> _enteredRows = {};

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
        //display_order 0 is the profile picture, which has no story
        _photos = photos.where((p) => p.displayOrder != 0).toList();
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
    final result = await showStoryDialog(context, initialStory: photo.story);

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
    return GlassScaffold(
      appBar: PageAppBar(title: text.photoStories),
      body: Crossfade(child: _body()),
    );
  }

  Widget _message(
    String key,
    IconData icon,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return CustomScrollView(
      key: ValueKey(key),
      slivers: [
        const SliverGlassBarInset(),
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: icon,
            message: message,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const _StoriesSkeleton(key: ValueKey('loading'));
    }

    if (_failed) {
      return _message(
        'failed',
        Icons.cloud_off_outlined,
        text.errorOccured,
        actionLabel: text.retry,
        onAction: _load,
      );
    }

    if (_photos.isEmpty) {
      return _message(
        'empty',
        Icons.photo_library_outlined,
        text.noPhotosYet,
      );
    }

    return GlassScroll(
      key: const ValueKey('list'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList.separated(
            //one extra leading item for the explanatory line
            itemCount: _photos.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Entrance(
                  shouldPlay: () => _enteredRows.add('intro'),
                  child: Text(
                    text.photoStoriesIntro,
                    style: mutedText(context),
                  ),
                );
              }
              final photo = _photos[index - 1];
              return Entrance(
                key: ValueKey(photo.photoUrl),
                order: Entrance.orderFor(index),
                shouldPlay: () => _enteredRows.add(photo.photoUrl),
                child: _StoryRow(photo: photo, onTap: () => _editStory(photo)),
              );
            },
          ),
        ),
      ],
    );
  }
}

//The intro line and a few rows, before the photos have arrived.
class _StoriesSkeleton extends StatelessWidget {
  const _StoriesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          const SliverGlassBarInset(),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  for (var i = 0; i < 4; i++)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 32),
                      child: Row(
                        children: [
                          Bone(width: 64, height: 88),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Bone(height: 16),
                                SizedBox(height: 8),
                                Bone(width: 96, height: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
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

    return SpringPress(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card,
        ),
        child: Material(
          //instant, not lerped - see widgets/nav_row.dart
          animationDuration: Duration.zero,
          color: theme.colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          clipBehavior: Clip.antiAlias,
          child: Pressable(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: CachedNetworkImage(
                      imageUrl: photo.photoUrl,
                      width: 64,
                      height: 88,
                      fit: BoxFit.cover,
                      //a sized placeholder, not a spinner: the row must not
                      //change height when the image lands, or the whole list
                      //jumps
                      placeholder: (_, _) => Container(
                        width: 64,
                        height: 88,
                        color: theme.colorScheme.surfaceContainerHigh,
                      ),
                      errorWidget: (_, _, _) => Container(
                        width: 64,
                        height: 88,
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      hasStory ? story : text.addStory,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: hasStory
                          ? theme.textTheme.bodyMedium
                          : mutedText(
                              context,
                            )?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    hasStory ? Icons.edit_outlined : Icons.add,
                    size: 24,
                    color: mutedInk(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
