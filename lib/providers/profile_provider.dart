//Provider that loads the profile of the user (photos, name, age)
//only used for profile related variables

import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:foitifinder/services/image_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

//Outcome of a profile picture update so the UI can give proper feedback.
//cancelled = user backed out of the picker (no error to show).
enum ProfilePictureUpdate { success, cancelled, failed }

//which API the cached profile was fetched from - see loadUser
const String _originKey = 'user_data_origin';

class ProfileProvider extends ChangeNotifier {
  final SharedPreferences _prefs; 
  File? _tempprofileImage; //to preview updates and check for changes
  UserModel? _currentUser;

  //The provider when initialized loads data from disk or if disk is empty loads null
  //Using this way we save the time of making a call to the db
  //99% of the time disk will be correct anyway
  ProfileProvider(this._prefs) {
    loadUser();
  }

  //image getter
  File? get tempProfileImage => _tempprofileImage;
  //user getter
  UserModel? get currentUser => _currentUser;

  //Load from disk
  //`uid` lets the caller supply the identity it has already established.
  //Relying only on FirebaseAuth.instance.currentUser was unsafe at startup: the
  //SDK restores the session asynchronously, so on a fast (release) launch this
  //could be null, silently skip the fetch, and leave _currentUser null — which
  //callers then read as "this account does not exist".
  Future<void> loadUser({String? uid}) async {
    //already have the user in memory (e.g. just registered during signup) ->
    //nothing to load, and crucially nothing to 404 on
    if (_currentUser != null) return;

    //THE CACHE BELONGS TO ONE BACKEND. SharedPreferences is per device, not
    //per database, so pointing the app at a different API leaves the previous
    //one's profile on disk and the app cannot tell: switching between a local
    //backend and the deployed one showed the other world's account, and
    //SetupWrapper routed off it - asking again for an Instagram handle that is
    //saved in the database it is NOT currently talking to.
    final cachedOrigin = _prefs.getString(_originKey);
    if (cachedOrigin != null && cachedOrigin != ApiService.baseUrl) {
      _prefs.remove('user_data');
      _prefs.remove(_originKey);
    }

    String? userJson = _prefs.getString('user_data');

    if(userJson != null) {
      try {
        Map<String, dynamic> userMap = jsonDecode(userJson);
        _currentUser = UserModel.fromJson(userMap);
      } catch (e) {
        //Unreadable cache (corrupt, or written by a build whose shape we can
        //no longer parse). Dropping it was not enough on its own: _currentUser
        //stayed null, and SetupWrapper reads a null user with no load error as
        //"this account is gone" and signs out. Fall through to the network so
        //a bad cache costs one request instead of the user's session.
        _prefs.remove('user_data');
      }
    }

    if (_currentUser == null) {
      final resolvedUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
      if(resolvedUid != null) {
        //await so currentUser is actually populated before callers read it
        //(SetupWrapper routes based on the return value of this)
        await fetchUserFromApi(resolvedUid);
      }
    }
  }

  //Load user data from postgres database and also store them in prefs if empty or different
  Future<void> fetchUserFromApi(String uid) async {
    
    UserModel? user = await ApiService.getUserData(uid);

    if(user != null) {
      _currentUser = user;
      notifyListeners();

      await _prefs.setString('user_data', jsonEncode(user.toMap()));
      //stamped with where it came from, so the check in loadUser can tell
      await _prefs.setString(_originKey, ApiService.baseUrl);
    }
  }

  //Change the profile picture from the profile page.
  //
  //The profile picture IS photo 0, so this replaces photo 0 and syncs the
  //whole list - the same thing Edit Profile does when the first slot changes.
  //Either place changes the one picture. The rest of the photos are untouched.
  //
  //Returns a result so the caller can show feedback instead of failing silently.
  Future<ProfilePictureUpdate> updateProfilePicture() async {
    File? file;
    try {
      file = await ImageService.pickImage();
    } catch (e) {
      //picker can throw (e.g. denied gallery permission)
      return ProfilePictureUpdate.failed;
    }
    //user cancelled the picker
    if (file == null) return ProfilePictureUpdate.cancelled;

    final user = _currentUser;
    if (user == null) return ProfilePictureUpdate.failed;

    //show the picked file straight away while it uploads
    _tempprofileImage = file;
    notifyListeners();

    try {
      final String? url = await ApiService.uploadToFirebase(file, user.uid);
      if (url == null) throw Exception('upload failed');

      //The list comes from the BACKEND, not the cached user. Sync replaces the
      //whole set, so a stale or empty cached list (a cache written before
      //photo_urls existed, or an offline launch) would delete every photo but
      //the new one.
      final current = await ApiService.getPhotos(user.uid);
      final photoUrls = [url, ...current.skip(1).map((p) => p.photoUrl)];
      final synced =
          await ApiService.syncPhotos(uid: user.uid, photoUrls: photoUrls);
      if (!synced) throw Exception('sync failed');

      //clear the preview in the same notify as the new url lands, so the
      //avatar never flashes back to the old picture in between
      _tempprofileImage = null;
      setPhotoUrls(photoUrls);
      return ProfilePictureUpdate.success;
    } catch (e) {
      //nothing was saved: drop the preview, the old picture is still correct
      _tempprofileImage = null;
      notifyListeners();
      return ProfilePictureUpdate.failed;
    }
  }

  //Take a photo list that has ALREADY been synced to the backend (Edit Profile,
  //or updateProfilePicture above). Memory and disk only.
  void setPhotoUrls(List<String> photoUrls) {
    final user = _currentUser;
    if (user == null) return;
    _setLocalUser(user.copyWith(photoUrls: List.unmodifiable(photoUrls)));
  }

  //Register new user on sign up
  Future<void> registerUser({
    required String uid,
    required String name,
    required bool hasFinishedSetUp,
    required bool hasPhotos,
    String? bio,
    DateTime? birthday,
    int? heightCm,
    String? city,
    String? gender,
    int? minAgeRange,
    int? maxAgeRange,
    String? preferredGender,
  }) async {
      //Optimistically set the local user + cache BEFORE the backend round-trip,
      //so the auth router (SetupWrapper) immediately treats us as a valid,
      //logged-in user and doesn't sign us out while createUser is still in
      //flight (a GET would 404 until the POST commits).
      _currentUser = UserModel(
        uid: uid,
        name: name,
        hasFinishedSetUp: hasFinishedSetUp,
        bio: bio,
        birthday: birthday,
        heightCm: heightCm,
        city: city,
        gender: gender,
        minAgeRange: minAgeRange,
        maxAgeRange: maxAgeRange,
        preferredGender: preferredGender,
        hasPhotos: hasPhotos,
      );
      notifyListeners();
      await _prefs.setString('user_data', jsonEncode(_currentUser!.toMap()));

      try {
        await ApiService.createUser(
          uid: uid,
          name: name,
          hasFinishedSetUp: hasFinishedSetUp,
          bio: bio,
          birthday: birthday,
          heightCm: heightCm,
          city: city,
          gender: gender,
          minAgeRange: minAgeRange,
          maxAgeRange: maxAgeRange,
          preferredGender: preferredGender,
          hasPhotos: hasPhotos,
        );
      } catch (e) {
        //creation failed -> roll back the optimistic state; signUp deletes the
        //Firebase user and shows the error
        _currentUser = null;
        await _prefs.remove('user_data');
        notifyListeners();
        rethrow;
      }

  }

  //Show one change straight away, send it, and put the old value back if the
  //backend refuses. Returns false on failure so the caller can say so.
  //
  //[read] and [write] pick out a SINGLE field, so a revert only ever touches
  //that field: a different edit that succeeded in the meantime is left alone.
  //The revert is also skipped when the field no longer holds this value, i.e.
  //a newer edit of the same field has already replaced it.
  Future<bool> saveField<T>({
    required T Function(UserModel user) read,
    required UserModel Function(UserModel user, T value) write,
    required T value,
    required Future<void> Function(String uid) send,
  }) async {
    final user = _currentUser;
    if (user == null) return false;
    final previous = read(user);

    _setLocalUser(write(user, value));

    try {
      await send(user.uid);
      return true;
    } catch (_) {
      final current = _currentUser;
      //logged out, or someone else logged in, while the request was out
      if (current == null || current.uid != user.uid) return false;
      if (read(current) == value) {
        _setLocalUser(write(current, previous));
      }
      return false;
    }
  }

  void _setLocalUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
    //not awaited: the disk copy is only a cache, the screen must not wait on it
    _prefs.setString('user_data', jsonEncode(user.toMap()));
  }

  //Update users data (sync with database)
  void updateLocalUser({
    String? name,
    String? bio,
    DateTime? birthday,
    int? heightCm,
    String? city,
    String? gender,
    bool? hasFinishedSetUp,
    bool? hasPhotos,
  }) async {
    if(currentUser == null)return;

    //copyWith carries every other field over. This used to build a UserModel
    //by hand, where any field left out was silently reset to null.
    _currentUser = _currentUser!.copyWith(
      name: name,
      bio: bio == null ? null : () => bio,
      birthday: birthday == null ? null : () => birthday,
      heightCm: heightCm == null ? null : () => heightCm,
      //null means "not being changed"; an empty string means "cleared", and is
      //normalised to null so local state matches what the backend stores
      city: city == null ? null : () => city.isEmpty ? null : city,
      gender: gender == null ? null : () => gender,
      hasFinishedSetUp: hasFinishedSetUp,
      hasPhotos: hasPhotos,
    );

    notifyListeners();

    await _prefs.setString('user_data', jsonEncode(_currentUser!.toMap()));
  }

  //Clear all data (used on logout)
  Future<void> clearData() async {
    _currentUser = null;
    _tempprofileImage = null;
    await _prefs.clear();
    notifyListeners();
  }
}