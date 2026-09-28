//The profile as other people see it - the View half of the edit page.
//
//A BODY, NOT A PAGE: no Scaffold and no app bar, because it lives inside the
//edit page's PageView. That is what lets the header stay still while this
//slides in beneath it.
//
//It draws ProfileDetailsBody, the same widget the page behind a swipe card
//uses, so this really is a preview and not a lookalike. All it owns is the
//header photo, which is framed differently here (it sits under the tabs) than
//over there (it runs to the top of the screen).
//
//READS FROM ProfileProvider, so it cannot show something the profile does not
//have. Edit a tag, swipe across, and it is already right. The ONE thing it
//fetches itself is the photo stories, which live on the photo rows rather than
//on the user - and they arrive after the layout, never changing it.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/models/public_profile.dart';
import 'package:foitifinder/pages/profile_pages/view_profile/profile_details_body.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:provider/provider.dart';

//how much of the screen the header photo takes here
const double _kFirstPhotoFraction = 0.45;
//how far the first card is lifted over the bottom of it
const double _kCardOverlap = 28;

class ViewProfileBody extends StatefulWidget {
  const ViewProfileBody({super.key});

  @override
  State<ViewProfileBody> createState() => _ViewProfileBodyState();
}

class _ViewProfileBodyState extends State<ViewProfileBody> {
  //photo url -> story. Empty until the fetch lands; the page never waits for
  //it, because the photos themselves come from the cached user.
  Map<String, String> _stories = const {};

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    try {
      final photos = await ApiService.getPhotos(
        FirebaseAuth.instance.currentUser?.uid ?? '',
      );
      if (!mounted) return;
      setState(() {
        _stories = {
          for (final photo in photos)
            if ((photo.story ?? '').trim().isNotEmpty)
              photo.photoUrl: photo.story!.trim(),
        };
      });
    } catch (_) {
      //no stories shown, nothing else changes. They are captions, not content
      //the page depends on.
    }
  }

  @override
  Widget build(BuildContext context) {
    //watch, not read: a save on the edit side must redraw this
    final user = Provider.of<ProfileProvider>(context).currentUser;
    if (user == null) return const SizedBox.shrink();

    final profile = PublicProfile.fromUser(user, stories: _stories);
    final photoHeight = MediaQuery.sizeOf(context).height * _kFirstPhotoFraction;

    return SingleChildScrollView(
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: photoHeight,
            child: _HeaderPhoto(url: profile.profilePictureUrl),
          ),
          //the profile starts one overlap ABOVE the bottom of the photo, so
          //the first card's top edge crops into it
          Padding(
            padding: EdgeInsets.only(top: photoHeight - _kCardOverlap),
            child: Column(
              children: [
                ProfileDetailsBody(profile: profile),
                //room to scroll past the last block
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPhoto extends StatelessWidget {
  final String? url;

  const _HeaderPhoto({required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.person_outline,
          size: 64,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    if (url == null) return placeholder;

    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      //a block of the right size, not a spinner: nothing below must jump when
      //the image lands
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}
