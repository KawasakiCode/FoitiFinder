import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_el.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('el'),
    Locale('en'),
  ];

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @discovery.
  ///
  /// In en, this message translates to:
  /// **'Discovery Settings'**
  String get discovery;

  /// No description provided for @interests.
  ///
  /// In en, this message translates to:
  /// **'Interested In'**
  String get interests;

  /// No description provided for @emptyInterests.
  ///
  /// In en, this message translates to:
  /// **'Interests show here'**
  String get emptyInterests;

  /// No description provided for @men.
  ///
  /// In en, this message translates to:
  /// **'Men'**
  String get men;

  /// No description provided for @women.
  ///
  /// In en, this message translates to:
  /// **'Women'**
  String get women;

  /// No description provided for @everybody.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get everybody;

  /// No description provided for @ageRange.
  ///
  /// In en, this message translates to:
  /// **'Age Range'**
  String get ageRange;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @greek.
  ///
  /// In en, this message translates to:
  /// **'Greek'**
  String get greek;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contact;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get help;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report a bug'**
  String get report;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @cookie.
  ///
  /// In en, this message translates to:
  /// **'Cookie Policy'**
  String get cookie;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get terms;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @interestedIn.
  ///
  /// In en, this message translates to:
  /// **'Interested In'**
  String get interestedIn;

  /// No description provided for @selectInterests.
  ///
  /// In en, this message translates to:
  /// **'Select all that apply for you'**
  String get selectInterests;

  /// No description provided for @sureDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account?'**
  String get sureDeleteAccount;

  /// No description provided for @deleteAccountLongText.
  ///
  /// In en, this message translates to:
  /// **'Your profile will be removed from FoitiFinder and won\'t be visible to other members. If you change your mind within 10 days, you can sign in to recover your account. After 10 days we will delete your data in accordance with our Privacy Policy and you will no longer be able to recover your profile.'**
  String get deleteAccountLongText;

  /// No description provided for @readPolicy.
  ///
  /// In en, this message translates to:
  /// **'Read our '**
  String get readPolicy;

  /// No description provided for @snackbarEnterPasswordToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password to confirm.'**
  String get snackbarEnterPasswordToConfirm;

  /// No description provided for @snackbarSuccessDeletion.
  ///
  /// In en, this message translates to:
  /// **'Your account has been successfully deleted.'**
  String get snackbarSuccessDeletion;

  /// No description provided for @incorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get incorrectPassword;

  /// No description provided for @invalidPassword.
  ///
  /// In en, this message translates to:
  /// **'Invalid password. Please try again.'**
  String get invalidPassword;

  /// No description provided for @requiresRecentLogin.
  ///
  /// In en, this message translates to:
  /// **'For security reasons, please log out and log back in before deleting your account.'**
  String get requiresRecentLogin;

  /// No description provided for @userNotFound.
  ///
  /// In en, this message translates to:
  /// **'User account not found.'**
  String get userNotFound;

  /// No description provided for @credentialsDontMatchUser.
  ///
  /// In en, this message translates to:
  /// **'The provided credentials do not match the current user.'**
  String get credentialsDontMatchUser;

  /// No description provided for @generalError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while deleting your account:'**
  String get generalError;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred:'**
  String get unexpectedError;

  /// No description provided for @deleteMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete My Account'**
  String get deleteMyAccount;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm'**
  String get enterPassword;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password. Please check your credentials and try again.'**
  String get invalidCredentials;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get invalidEmail;

  /// No description provided for @disabledAccount.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get disabledAccount;

  /// No description provided for @tooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Please try again later.'**
  String get tooManyRequests;

  /// No description provided for @errorOccured.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get errorOccured;

  /// No description provided for @passwordResetEmail.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Please check your email.'**
  String get passwordResetEmail;

  /// No description provided for @signUpLongText.
  ///
  /// In en, this message translates to:
  /// **'By signing up, you agree to our AI generated terms of service and Privacy Policy. Learn how we steal your data and sell them to shady multibillion dollar companies '**
  String get signUpLongText;

  /// No description provided for @here.
  ///
  /// In en, this message translates to:
  /// **'here'**
  String get here;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Have an account?'**
  String get haveAccount;

  /// No description provided for @smallPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters long.'**
  String get smallPassword;

  /// No description provided for @emailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Please try logging in instead.'**
  String get emailAlreadyInUse;

  /// No description provided for @weakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Please choose a stronger password (at least 8 characters)'**
  String get weakPassword;

  /// No description provided for @operationNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Email/password accounts are not enabled. Please contact support.'**
  String get operationNotAllowed;

  /// No description provided for @signUpError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred during signup. Please try again.'**
  String get signUpError;

  /// No description provided for @verifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email address'**
  String get verifyEmail;

  /// No description provided for @verificationEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent! Please check your inbox.'**
  String get verificationEmailSent;

  /// No description provided for @snackbarSuccessVerifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent successfully!'**
  String get snackbarSuccessVerifyEmail;

  /// No description provided for @snackbarFailedVerifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Failed to send verification email. Please try again.'**
  String get snackbarFailedVerifyEmail;

  /// No description provided for @sentVerificationEmail.
  ///
  /// In en, this message translates to:
  /// **'Sent Verification Email'**
  String get sentVerificationEmail;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get backToLogin;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @securityCheck.
  ///
  /// In en, this message translates to:
  /// **'Security Check'**
  String get securityCheck;

  /// No description provided for @notificationsWarning.
  ///
  /// In en, this message translates to:
  /// **' Requires notifications permission from device'**
  String get notificationsWarning;

  /// No description provided for @addAge.
  ///
  /// In en, this message translates to:
  /// **'Add your age'**
  String get addAge;

  /// No description provided for @addBio.
  ///
  /// In en, this message translates to:
  /// **'Add your bio'**
  String get addBio;

  /// No description provided for @addGender.
  ///
  /// In en, this message translates to:
  /// **'Select your gender'**
  String get addGender;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @noMoreProfiles.
  ///
  /// In en, this message translates to:
  /// **'No more profiles to show!'**
  String get noMoreProfiles;

  /// No description provided for @checkLater.
  ///
  /// In en, this message translates to:
  /// **'Check back later for new matches'**
  String get checkLater;

  /// No description provided for @signUpText.
  ///
  /// In en, this message translates to:
  /// **'Sign up to continue'**
  String get signUpText;

  /// No description provided for @addPhotoText.
  ///
  /// In en, this message translates to:
  /// **'Please add at least one photo'**
  String get addPhotoText;

  /// No description provided for @itsAMatch.
  ///
  /// In en, this message translates to:
  /// **'It\'s a match!'**
  String get itsAMatch;

  /// No description provided for @matchText1.
  ///
  /// In en, this message translates to:
  /// **'You and '**
  String get matchText1;

  /// No description provided for @matchText2.
  ///
  /// In en, this message translates to:
  /// **' liked each other!'**
  String get matchText2;

  /// No description provided for @uploadPhotos.
  ///
  /// In en, this message translates to:
  /// **'Upload Your Photos'**
  String get uploadPhotos;

  /// No description provided for @addAtLeastAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add at least one photo to continue'**
  String get addAtLeastAPhoto;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @verifyYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get verifyYourEmail;

  /// No description provided for @likeNotifications.
  ///
  /// In en, this message translates to:
  /// **'Like and Match Notifications'**
  String get likeNotifications;

  /// No description provided for @emptyEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter an email'**
  String get emptyEmail;

  /// No description provided for @emptyPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get emptyPassword;

  /// No description provided for @emptyFields.
  ///
  /// In en, this message translates to:
  /// **'Please enter your credentials'**
  String get emptyFields;

  /// No description provided for @lostInternet.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get lostInternet;

  /// No description provided for @nameRestriction.
  ///
  /// In en, this message translates to:
  /// **'Full Names can only contain letters, spaces, dashes and apostrophes and begin with a letter'**
  String get nameRestriction;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in'**
  String get resendIn;

  /// No description provided for @requestTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Please try again'**
  String get requestTimedOut;

  /// No description provided for @backOnline.
  ///
  /// In en, this message translates to:
  /// **'You are back online'**
  String get backOnline;

  /// No description provided for @unsupportedFileType.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file type. Please select a JPG or PNG'**
  String get unsupportedFileType;

  /// No description provided for @invalidAge.
  ///
  /// In en, this message translates to:
  /// **'Age must be between 18 and 99 years old'**
  String get invalidAge;

  /// No description provided for @mailVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified Email'**
  String get mailVerified;

  /// No description provided for @noLikes.
  ///
  /// In en, this message translates to:
  /// **'Your likes will appear here'**
  String get noLikes;

  /// No description provided for @notSupportedDomain.
  ///
  /// In en, this message translates to:
  /// **'Only university emails are allowed'**
  String get notSupportedDomain;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @lblHobbiesInterests.
  ///
  /// In en, this message translates to:
  /// **'Hobbies & interests'**
  String get lblHobbiesInterests;

  /// No description provided for @lblTraits.
  ///
  /// In en, this message translates to:
  /// **'Traits'**
  String get lblTraits;

  /// No description provided for @lblBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get lblBio;

  /// No description provided for @lblActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get lblActivities;

  /// No description provided for @lblInterests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get lblInterests;

  /// No description provided for @lblEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get lblEntertainment;

  /// No description provided for @lblCreative.
  ///
  /// In en, this message translates to:
  /// **'Creative'**
  String get lblCreative;

  /// No description provided for @lblMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get lblMusic;

  /// No description provided for @lblFoodDrinks.
  ///
  /// In en, this message translates to:
  /// **'Food & drinks'**
  String get lblFoodDrinks;

  /// No description provided for @lblSports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get lblSports;

  /// No description provided for @lblPersonalityTraits.
  ///
  /// In en, this message translates to:
  /// **'Personality traits'**
  String get lblPersonalityTraits;

  /// No description provided for @lblStarSign.
  ///
  /// In en, this message translates to:
  /// **'Star sign'**
  String get lblStarSign;

  /// No description provided for @lblPersonalityTypeMBTI.
  ///
  /// In en, this message translates to:
  /// **'Personality type (MBTI)'**
  String get lblPersonalityTypeMBTI;

  /// No description provided for @lblLifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle'**
  String get lblLifestyle;

  /// No description provided for @lblBaking.
  ///
  /// In en, this message translates to:
  /// **'Baking'**
  String get lblBaking;

  /// No description provided for @lblBeach.
  ///
  /// In en, this message translates to:
  /// **'Beach'**
  String get lblBeach;

  /// No description provided for @lblCamping.
  ///
  /// In en, this message translates to:
  /// **'Camping'**
  String get lblCamping;

  /// No description provided for @lblCityTrips.
  ///
  /// In en, this message translates to:
  /// **'City trips'**
  String get lblCityTrips;

  /// No description provided for @lblConcerts.
  ///
  /// In en, this message translates to:
  /// **'Concerts'**
  String get lblConcerts;

  /// No description provided for @lblCooking.
  ///
  /// In en, this message translates to:
  /// **'Cooking'**
  String get lblCooking;

  /// No description provided for @lblDiningOut.
  ///
  /// In en, this message translates to:
  /// **'Dining out'**
  String get lblDiningOut;

  /// No description provided for @lblDinnerParties.
  ///
  /// In en, this message translates to:
  /// **'Dinner parties'**
  String get lblDinnerParties;

  /// No description provided for @lblFestivals.
  ///
  /// In en, this message translates to:
  /// **'Festivals'**
  String get lblFestivals;

  /// No description provided for @lblHavingDrinks.
  ///
  /// In en, this message translates to:
  /// **'Having drinks'**
  String get lblHavingDrinks;

  /// No description provided for @lblHiking.
  ///
  /// In en, this message translates to:
  /// **'Hiking'**
  String get lblHiking;

  /// No description provided for @lblKaraoke.
  ///
  /// In en, this message translates to:
  /// **'Karaoke'**
  String get lblKaraoke;

  /// No description provided for @lblMeditation.
  ///
  /// In en, this message translates to:
  /// **'Meditation'**
  String get lblMeditation;

  /// No description provided for @lblMountains.
  ///
  /// In en, this message translates to:
  /// **'Mountains'**
  String get lblMountains;

  /// No description provided for @lblMuseum.
  ///
  /// In en, this message translates to:
  /// **'Museum'**
  String get lblMuseum;

  /// No description provided for @lblOutdoors.
  ///
  /// In en, this message translates to:
  /// **'Outdoors'**
  String get lblOutdoors;

  /// No description provided for @lblParty.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get lblParty;

  /// No description provided for @lblResortVacations.
  ///
  /// In en, this message translates to:
  /// **'Resort vacations'**
  String get lblResortVacations;

  /// No description provided for @lblSauna.
  ///
  /// In en, this message translates to:
  /// **'Sauna'**
  String get lblSauna;

  /// No description provided for @lblShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get lblShopping;

  /// No description provided for @lblTakingAWalk.
  ///
  /// In en, this message translates to:
  /// **'Taking a walk'**
  String get lblTakingAWalk;

  /// No description provided for @lblThrifting.
  ///
  /// In en, this message translates to:
  /// **'Thrifting'**
  String get lblThrifting;

  /// No description provided for @lblTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get lblTravel;

  /// No description provided for @lblWellness.
  ///
  /// In en, this message translates to:
  /// **'Wellness'**
  String get lblWellness;

  /// No description provided for @lblProgramming.
  ///
  /// In en, this message translates to:
  /// **'Programming'**
  String get lblProgramming;

  /// No description provided for @lblAI.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get lblAI;

  /// No description provided for @lblAnimals.
  ///
  /// In en, this message translates to:
  /// **'Animals'**
  String get lblAnimals;

  /// No description provided for @lblArchitecture.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get lblArchitecture;

  /// No description provided for @lblArt.
  ///
  /// In en, this message translates to:
  /// **'Art'**
  String get lblArt;

  /// No description provided for @lblBiology.
  ///
  /// In en, this message translates to:
  /// **'Biology'**
  String get lblBiology;

  /// No description provided for @lblCars.
  ///
  /// In en, this message translates to:
  /// **'Cars'**
  String get lblCars;

  /// No description provided for @lblCats.
  ///
  /// In en, this message translates to:
  /// **'Cats'**
  String get lblCats;

  /// No description provided for @lblCinema.
  ///
  /// In en, this message translates to:
  /// **'Cinema'**
  String get lblCinema;

  /// No description provided for @lblDogs.
  ///
  /// In en, this message translates to:
  /// **'Dogs'**
  String get lblDogs;

  /// No description provided for @lblEntrepreneurship.
  ///
  /// In en, this message translates to:
  /// **'Entrepreneurship'**
  String get lblEntrepreneurship;

  /// No description provided for @lblFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get lblFinance;

  /// No description provided for @lblHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get lblHistory;

  /// No description provided for @lblHorses.
  ///
  /// In en, this message translates to:
  /// **'Horses'**
  String get lblHorses;

  /// No description provided for @lblLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get lblLanguage;

  /// No description provided for @lblNature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get lblNature;

  /// No description provided for @lblPersonalDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Personal development'**
  String get lblPersonalDevelopment;

  /// No description provided for @lblPhilosophy.
  ///
  /// In en, this message translates to:
  /// **'Philosophy'**
  String get lblPhilosophy;

  /// No description provided for @lblPlants.
  ///
  /// In en, this message translates to:
  /// **'Plants'**
  String get lblPlants;

  /// No description provided for @lblPolitics.
  ///
  /// In en, this message translates to:
  /// **'Politics'**
  String get lblPolitics;

  /// No description provided for @lblPsychology.
  ///
  /// In en, this message translates to:
  /// **'Psychology'**
  String get lblPsychology;

  /// No description provided for @lblScience.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get lblScience;

  /// No description provided for @lblSustainability.
  ///
  /// In en, this message translates to:
  /// **'Sustainability'**
  String get lblSustainability;

  /// No description provided for @lblTattoos.
  ///
  /// In en, this message translates to:
  /// **'Tattoos'**
  String get lblTattoos;

  /// No description provided for @lblTech.
  ///
  /// In en, this message translates to:
  /// **'Tech'**
  String get lblTech;

  /// No description provided for @lblTheatre.
  ///
  /// In en, this message translates to:
  /// **'Theatre'**
  String get lblTheatre;

  /// No description provided for @lblReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get lblReading;

  /// No description provided for @lblBoardGames.
  ///
  /// In en, this message translates to:
  /// **'Board games'**
  String get lblBoardGames;

  /// No description provided for @lblCartoons.
  ///
  /// In en, this message translates to:
  /// **'Cartoons'**
  String get lblCartoons;

  /// No description provided for @lblChess.
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get lblChess;

  /// No description provided for @lblComedy.
  ///
  /// In en, this message translates to:
  /// **'Comedy'**
  String get lblComedy;

  /// No description provided for @lblComics.
  ///
  /// In en, this message translates to:
  /// **'Comics'**
  String get lblComics;

  /// No description provided for @lblDocumentaries.
  ///
  /// In en, this message translates to:
  /// **'Documentaries'**
  String get lblDocumentaries;

  /// No description provided for @lblHorror.
  ///
  /// In en, this message translates to:
  /// **'Horror'**
  String get lblHorror;

  /// No description provided for @lblMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get lblMovies;

  /// No description provided for @lblMusicals.
  ///
  /// In en, this message translates to:
  /// **'Musicals'**
  String get lblMusicals;

  /// No description provided for @lblPuzzles.
  ///
  /// In en, this message translates to:
  /// **'Puzzles'**
  String get lblPuzzles;

  /// No description provided for @lblSciFi.
  ///
  /// In en, this message translates to:
  /// **'Sci-fi'**
  String get lblSciFi;

  /// No description provided for @lblSitcoms.
  ///
  /// In en, this message translates to:
  /// **'Sitcoms'**
  String get lblSitcoms;

  /// No description provided for @lblVinylRecords.
  ///
  /// In en, this message translates to:
  /// **'Vinyl records'**
  String get lblVinylRecords;

  /// No description provided for @lblPlayingInstruments.
  ///
  /// In en, this message translates to:
  /// **'Playing instruments'**
  String get lblPlayingInstruments;

  /// No description provided for @lblActing.
  ///
  /// In en, this message translates to:
  /// **'Acting'**
  String get lblActing;

  /// No description provided for @lblComposingMusic.
  ///
  /// In en, this message translates to:
  /// **'Composing music'**
  String get lblComposingMusic;

  /// No description provided for @lblCrafts.
  ///
  /// In en, this message translates to:
  /// **'Crafts'**
  String get lblCrafts;

  /// No description provided for @lblDesign.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get lblDesign;

  /// No description provided for @lblDrawing.
  ///
  /// In en, this message translates to:
  /// **'Drawing'**
  String get lblDrawing;

  /// No description provided for @lblFashion.
  ///
  /// In en, this message translates to:
  /// **'Fashion'**
  String get lblFashion;

  /// No description provided for @lblKnitting.
  ///
  /// In en, this message translates to:
  /// **'Knitting'**
  String get lblKnitting;

  /// No description provided for @lblPainting.
  ///
  /// In en, this message translates to:
  /// **'Painting'**
  String get lblPainting;

  /// No description provided for @lblPhotography.
  ///
  /// In en, this message translates to:
  /// **'Photography'**
  String get lblPhotography;

  /// No description provided for @lblPoetry.
  ///
  /// In en, this message translates to:
  /// **'Poetry'**
  String get lblPoetry;

  /// No description provided for @lblPottery.
  ///
  /// In en, this message translates to:
  /// **'Pottery'**
  String get lblPottery;

  /// No description provided for @lblSewing.
  ///
  /// In en, this message translates to:
  /// **'Sewing'**
  String get lblSewing;

  /// No description provided for @lblSinging.
  ///
  /// In en, this message translates to:
  /// **'Singing'**
  String get lblSinging;

  /// No description provided for @lblWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing'**
  String get lblWriting;

  /// No description provided for @lblClassicalMusic.
  ///
  /// In en, this message translates to:
  /// **'Classical music'**
  String get lblClassicalMusic;

  /// No description provided for @lblCountryMusic.
  ///
  /// In en, this message translates to:
  /// **'Country music'**
  String get lblCountryMusic;

  /// No description provided for @lblDrums.
  ///
  /// In en, this message translates to:
  /// **'Drums'**
  String get lblDrums;

  /// No description provided for @lblGuitar.
  ///
  /// In en, this message translates to:
  /// **'Guitar'**
  String get lblGuitar;

  /// No description provided for @lblIndieMusic.
  ///
  /// In en, this message translates to:
  /// **'Indie music'**
  String get lblIndieMusic;

  /// No description provided for @lblLatinMusic.
  ///
  /// In en, this message translates to:
  /// **'Latin music'**
  String get lblLatinMusic;

  /// No description provided for @lblPiano.
  ///
  /// In en, this message translates to:
  /// **'Piano'**
  String get lblPiano;

  /// No description provided for @lblPopMusic.
  ///
  /// In en, this message translates to:
  /// **'Pop music'**
  String get lblPopMusic;

  /// No description provided for @lblBeer.
  ///
  /// In en, this message translates to:
  /// **'Beer'**
  String get lblBeer;

  /// No description provided for @lblChampagne.
  ///
  /// In en, this message translates to:
  /// **'Champagne'**
  String get lblChampagne;

  /// No description provided for @lblCheese.
  ///
  /// In en, this message translates to:
  /// **'Cheese'**
  String get lblCheese;

  /// No description provided for @lblChocolate.
  ///
  /// In en, this message translates to:
  /// **'Chocolate'**
  String get lblChocolate;

  /// No description provided for @lblCocktails.
  ///
  /// In en, this message translates to:
  /// **'Cocktails'**
  String get lblCocktails;

  /// No description provided for @lblCoffee.
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get lblCoffee;

  /// No description provided for @lblCraftBeers.
  ///
  /// In en, this message translates to:
  /// **'Craft beers'**
  String get lblCraftBeers;

  /// No description provided for @lblTea.
  ///
  /// In en, this message translates to:
  /// **'Tea'**
  String get lblTea;

  /// No description provided for @lblWhiskey.
  ///
  /// In en, this message translates to:
  /// **'Whiskey'**
  String get lblWhiskey;

  /// No description provided for @lblWine.
  ///
  /// In en, this message translates to:
  /// **'Wine'**
  String get lblWine;

  /// No description provided for @lblMartialArts.
  ///
  /// In en, this message translates to:
  /// **'Martial arts'**
  String get lblMartialArts;

  /// No description provided for @lblAthletics.
  ///
  /// In en, this message translates to:
  /// **'Athletics'**
  String get lblAthletics;

  /// No description provided for @lblBadminton.
  ///
  /// In en, this message translates to:
  /// **'Badminton'**
  String get lblBadminton;

  /// No description provided for @lblBallet.
  ///
  /// In en, this message translates to:
  /// **'Ballet'**
  String get lblBallet;

  /// No description provided for @lblBaseball.
  ///
  /// In en, this message translates to:
  /// **'Baseball'**
  String get lblBaseball;

  /// No description provided for @lblBasketball.
  ///
  /// In en, this message translates to:
  /// **'Basketball'**
  String get lblBasketball;

  /// No description provided for @lblBowling.
  ///
  /// In en, this message translates to:
  /// **'Bowling'**
  String get lblBowling;

  /// No description provided for @lblClimbing.
  ///
  /// In en, this message translates to:
  /// **'Climbing'**
  String get lblClimbing;

  /// No description provided for @lblCricket.
  ///
  /// In en, this message translates to:
  /// **'Cricket'**
  String get lblCricket;

  /// No description provided for @lblCycling.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get lblCycling;

  /// No description provided for @lblDancing.
  ///
  /// In en, this message translates to:
  /// **'Dancing'**
  String get lblDancing;

  /// No description provided for @lblFencing.
  ///
  /// In en, this message translates to:
  /// **'Fencing'**
  String get lblFencing;

  /// No description provided for @lblFitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get lblFitness;

  /// No description provided for @lblFootball.
  ///
  /// In en, this message translates to:
  /// **'Football'**
  String get lblFootball;

  /// No description provided for @lblGolf.
  ///
  /// In en, this message translates to:
  /// **'Golf'**
  String get lblGolf;

  /// No description provided for @lblHandball.
  ///
  /// In en, this message translates to:
  /// **'Handball'**
  String get lblHandball;

  /// No description provided for @lblHockey.
  ///
  /// In en, this message translates to:
  /// **'Hockey'**
  String get lblHockey;

  /// No description provided for @lblHorseRiding.
  ///
  /// In en, this message translates to:
  /// **'Horse riding'**
  String get lblHorseRiding;

  /// No description provided for @lblIceSkating.
  ///
  /// In en, this message translates to:
  /// **'Ice skating'**
  String get lblIceSkating;

  /// No description provided for @lblKayaking.
  ///
  /// In en, this message translates to:
  /// **'Kayaking'**
  String get lblKayaking;

  /// No description provided for @lblMotorcycling.
  ///
  /// In en, this message translates to:
  /// **'Motorcycling'**
  String get lblMotorcycling;

  /// No description provided for @lblMountainbiking.
  ///
  /// In en, this message translates to:
  /// **'Mountainbiking'**
  String get lblMountainbiking;

  /// No description provided for @lblPilates.
  ///
  /// In en, this message translates to:
  /// **'Pilates'**
  String get lblPilates;

  /// No description provided for @lblRowing.
  ///
  /// In en, this message translates to:
  /// **'Rowing'**
  String get lblRowing;

  /// No description provided for @lblRugby.
  ///
  /// In en, this message translates to:
  /// **'Rugby'**
  String get lblRugby;

  /// No description provided for @lblRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get lblRunning;

  /// No description provided for @lblSailing.
  ///
  /// In en, this message translates to:
  /// **'Sailing'**
  String get lblSailing;

  /// No description provided for @lblScubaDiving.
  ///
  /// In en, this message translates to:
  /// **'Scuba diving'**
  String get lblScubaDiving;

  /// No description provided for @lblSkateboarding.
  ///
  /// In en, this message translates to:
  /// **'Skateboarding'**
  String get lblSkateboarding;

  /// No description provided for @lblSkiing.
  ///
  /// In en, this message translates to:
  /// **'Skiing'**
  String get lblSkiing;

  /// No description provided for @lblSnowboarding.
  ///
  /// In en, this message translates to:
  /// **'Snowboarding'**
  String get lblSnowboarding;

  /// No description provided for @lblSquash.
  ///
  /// In en, this message translates to:
  /// **'Squash'**
  String get lblSquash;

  /// No description provided for @lblSurfing.
  ///
  /// In en, this message translates to:
  /// **'Surfing'**
  String get lblSurfing;

  /// No description provided for @lblSwimming.
  ///
  /// In en, this message translates to:
  /// **'Swimming'**
  String get lblSwimming;

  /// No description provided for @lblTableTennis.
  ///
  /// In en, this message translates to:
  /// **'Table tennis'**
  String get lblTableTennis;

  /// No description provided for @lblTennis.
  ///
  /// In en, this message translates to:
  /// **'Tennis'**
  String get lblTennis;

  /// No description provided for @lblVolleyball.
  ///
  /// In en, this message translates to:
  /// **'Volleyball'**
  String get lblVolleyball;

  /// No description provided for @lblWaterpolo.
  ///
  /// In en, this message translates to:
  /// **'Waterpolo'**
  String get lblWaterpolo;

  /// No description provided for @lblWindsurfing.
  ///
  /// In en, this message translates to:
  /// **'Windsurfing'**
  String get lblWindsurfing;

  /// No description provided for @lblYoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get lblYoga;

  /// No description provided for @lblIntrovert.
  ///
  /// In en, this message translates to:
  /// **'Introvert'**
  String get lblIntrovert;

  /// No description provided for @lblAdventurous.
  ///
  /// In en, this message translates to:
  /// **'Adventurous'**
  String get lblAdventurous;

  /// No description provided for @lblAmbitious.
  ///
  /// In en, this message translates to:
  /// **'Ambitious'**
  String get lblAmbitious;

  /// No description provided for @lblAmbivert.
  ///
  /// In en, this message translates to:
  /// **'Ambivert'**
  String get lblAmbivert;

  /// No description provided for @lblCalm.
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get lblCalm;

  /// No description provided for @lblCaring.
  ///
  /// In en, this message translates to:
  /// **'Caring'**
  String get lblCaring;

  /// No description provided for @lblChaotic.
  ///
  /// In en, this message translates to:
  /// **'Chaotic'**
  String get lblChaotic;

  /// No description provided for @lblCompetitionSeeker.
  ///
  /// In en, this message translates to:
  /// **'Competition seeker'**
  String get lblCompetitionSeeker;

  /// No description provided for @lblCurious.
  ///
  /// In en, this message translates to:
  /// **'Curious'**
  String get lblCurious;

  /// No description provided for @lblDeepThinker.
  ///
  /// In en, this message translates to:
  /// **'Deep thinker'**
  String get lblDeepThinker;

  /// No description provided for @lblDreamer.
  ///
  /// In en, this message translates to:
  /// **'Dreamer'**
  String get lblDreamer;

  /// No description provided for @lblEmpathetic.
  ///
  /// In en, this message translates to:
  /// **'Empathetic'**
  String get lblEmpathetic;

  /// No description provided for @lblEnergetic.
  ///
  /// In en, this message translates to:
  /// **'Energetic'**
  String get lblEnergetic;

  /// No description provided for @lblExtravert.
  ///
  /// In en, this message translates to:
  /// **'Extravert'**
  String get lblExtravert;

  /// No description provided for @lblFlexible.
  ///
  /// In en, this message translates to:
  /// **'Flexible'**
  String get lblFlexible;

  /// No description provided for @lblGenerous.
  ///
  /// In en, this message translates to:
  /// **'Generous'**
  String get lblGenerous;

  /// No description provided for @lblGoGetter.
  ///
  /// In en, this message translates to:
  /// **'Go-getter'**
  String get lblGoGetter;

  /// No description provided for @lblHonest.
  ///
  /// In en, this message translates to:
  /// **'Honest'**
  String get lblHonest;

  /// No description provided for @lblKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get lblKind;

  /// No description provided for @lblListener.
  ///
  /// In en, this message translates to:
  /// **'Listener'**
  String get lblListener;

  /// No description provided for @lblOpenMinded.
  ///
  /// In en, this message translates to:
  /// **'Open-minded'**
  String get lblOpenMinded;

  /// No description provided for @lblOptimistic.
  ///
  /// In en, this message translates to:
  /// **'Optimistic'**
  String get lblOptimistic;

  /// No description provided for @lblOrganized.
  ///
  /// In en, this message translates to:
  /// **'Organized'**
  String get lblOrganized;

  /// No description provided for @lblOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing'**
  String get lblOutgoing;

  /// No description provided for @lblPassionate.
  ///
  /// In en, this message translates to:
  /// **'Passionate'**
  String get lblPassionate;

  /// No description provided for @lblPatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get lblPatient;

  /// No description provided for @lblPerfectionist.
  ///
  /// In en, this message translates to:
  /// **'Perfectionist'**
  String get lblPerfectionist;

  /// No description provided for @lblPlayful.
  ///
  /// In en, this message translates to:
  /// **'Playful'**
  String get lblPlayful;

  /// No description provided for @lblPositive.
  ///
  /// In en, this message translates to:
  /// **'Positive'**
  String get lblPositive;

  /// No description provided for @lblRomantic.
  ///
  /// In en, this message translates to:
  /// **'Romantic'**
  String get lblRomantic;

  /// No description provided for @lblSpontaneous.
  ///
  /// In en, this message translates to:
  /// **'Spontaneous'**
  String get lblSpontaneous;

  /// No description provided for @lblSupportive.
  ///
  /// In en, this message translates to:
  /// **'Supportive'**
  String get lblSupportive;

  /// No description provided for @lblWitty.
  ///
  /// In en, this message translates to:
  /// **'Witty'**
  String get lblWitty;

  /// No description provided for @lblAries.
  ///
  /// In en, this message translates to:
  /// **'Aries'**
  String get lblAries;

  /// No description provided for @lblTaurus.
  ///
  /// In en, this message translates to:
  /// **'Taurus'**
  String get lblTaurus;

  /// No description provided for @lblGemini.
  ///
  /// In en, this message translates to:
  /// **'Gemini'**
  String get lblGemini;

  /// No description provided for @lblCancer.
  ///
  /// In en, this message translates to:
  /// **'Cancer'**
  String get lblCancer;

  /// No description provided for @lblLeo.
  ///
  /// In en, this message translates to:
  /// **'Leo'**
  String get lblLeo;

  /// No description provided for @lblVirgo.
  ///
  /// In en, this message translates to:
  /// **'Virgo'**
  String get lblVirgo;

  /// No description provided for @lblLibra.
  ///
  /// In en, this message translates to:
  /// **'Libra'**
  String get lblLibra;

  /// No description provided for @lblScorpio.
  ///
  /// In en, this message translates to:
  /// **'Scorpio'**
  String get lblScorpio;

  /// No description provided for @lblSagittarius.
  ///
  /// In en, this message translates to:
  /// **'Sagittarius'**
  String get lblSagittarius;

  /// No description provided for @lblCapricorn.
  ///
  /// In en, this message translates to:
  /// **'Capricorn'**
  String get lblCapricorn;

  /// No description provided for @lblAquarius.
  ///
  /// In en, this message translates to:
  /// **'Aquarius'**
  String get lblAquarius;

  /// No description provided for @lblPisces.
  ///
  /// In en, this message translates to:
  /// **'Pisces'**
  String get lblPisces;

  /// No description provided for @lblEarlyBird.
  ///
  /// In en, this message translates to:
  /// **'Early bird'**
  String get lblEarlyBird;

  /// No description provided for @lblActivist.
  ///
  /// In en, this message translates to:
  /// **'Activist'**
  String get lblActivist;

  /// No description provided for @lblAnimalLover.
  ///
  /// In en, this message translates to:
  /// **'Animal lover'**
  String get lblAnimalLover;

  /// No description provided for @lblBohemian.
  ///
  /// In en, this message translates to:
  /// **'Bohemian'**
  String get lblBohemian;

  /// No description provided for @lblCorporate.
  ///
  /// In en, this message translates to:
  /// **'Corporate'**
  String get lblCorporate;

  /// No description provided for @lblCozyAtHome.
  ///
  /// In en, this message translates to:
  /// **'Cozy at home'**
  String get lblCozyAtHome;

  /// No description provided for @lblFamilyOrientated.
  ///
  /// In en, this message translates to:
  /// **'Family orientated'**
  String get lblFamilyOrientated;

  /// No description provided for @lblFoodie.
  ///
  /// In en, this message translates to:
  /// **'Foodie'**
  String get lblFoodie;

  /// No description provided for @lblHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get lblHealth;

  /// No description provided for @lblMaximalist.
  ///
  /// In en, this message translates to:
  /// **'Maximalist'**
  String get lblMaximalist;

  /// No description provided for @lblMinimalist.
  ///
  /// In en, this message translates to:
  /// **'Minimalist'**
  String get lblMinimalist;

  /// No description provided for @lblMusicLover.
  ///
  /// In en, this message translates to:
  /// **'Music lover'**
  String get lblMusicLover;

  /// No description provided for @lblNightOwl.
  ///
  /// In en, this message translates to:
  /// **'Night owl'**
  String get lblNightOwl;

  /// No description provided for @lblPetFree.
  ///
  /// In en, this message translates to:
  /// **'Pet free'**
  String get lblPetFree;

  /// No description provided for @lblSober.
  ///
  /// In en, this message translates to:
  /// **'Sober'**
  String get lblSober;

  /// No description provided for @lblSpiritual.
  ///
  /// In en, this message translates to:
  /// **'Spiritual'**
  String get lblSpiritual;

  /// No description provided for @lblSportive.
  ///
  /// In en, this message translates to:
  /// **'Sportive'**
  String get lblSportive;

  /// No description provided for @lblStudentAssociation.
  ///
  /// In en, this message translates to:
  /// **'Student association'**
  String get lblStudentAssociation;

  /// No description provided for @lblSustainable.
  ///
  /// In en, this message translates to:
  /// **'Sustainable'**
  String get lblSustainable;

  /// No description provided for @lblThrillSeeker.
  ///
  /// In en, this message translates to:
  /// **'Thrill seeker'**
  String get lblThrillSeeker;

  /// No description provided for @lblWanderlust.
  ///
  /// In en, this message translates to:
  /// **'Wanderlust'**
  String get lblWanderlust;

  /// No description provided for @lblAlcohol.
  ///
  /// In en, this message translates to:
  /// **'Alcohol'**
  String get lblAlcohol;

  /// No description provided for @lblHowOftenDoYouDrink.
  ///
  /// In en, this message translates to:
  /// **'How often do you drink?'**
  String get lblHowOftenDoYouDrink;

  /// No description provided for @lblSmoking.
  ///
  /// In en, this message translates to:
  /// **'Smoking'**
  String get lblSmoking;

  /// No description provided for @lblHowOftenDoYouSmoke.
  ///
  /// In en, this message translates to:
  /// **'How often do you smoke?'**
  String get lblHowOftenDoYouSmoke;

  /// No description provided for @lblDatingIntention.
  ///
  /// In en, this message translates to:
  /// **'Dating intention'**
  String get lblDatingIntention;

  /// No description provided for @lblWhatAreYouLookingFor.
  ///
  /// In en, this message translates to:
  /// **'What are you looking for?'**
  String get lblWhatAreYouLookingFor;

  /// No description provided for @lblKids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get lblKids;

  /// No description provided for @lblWhereDoYouStandOnChildren.
  ///
  /// In en, this message translates to:
  /// **'Where do you stand on children?'**
  String get lblWhereDoYouStandOnChildren;

  /// No description provided for @lblReligion.
  ///
  /// In en, this message translates to:
  /// **'Religion'**
  String get lblReligion;

  /// No description provided for @lblPickAnyThatApply.
  ///
  /// In en, this message translates to:
  /// **'Pick any that apply.'**
  String get lblPickAnyThatApply;

  /// No description provided for @lblPoliticalView.
  ///
  /// In en, this message translates to:
  /// **'Political view'**
  String get lblPoliticalView;

  /// No description provided for @lblSexualOrientation.
  ///
  /// In en, this message translates to:
  /// **'Sexual orientation'**
  String get lblSexualOrientation;

  /// No description provided for @lblHowDoYouIdentify.
  ///
  /// In en, this message translates to:
  /// **'How do you identify?'**
  String get lblHowDoYouIdentify;

  /// No description provided for @lblPronouns.
  ///
  /// In en, this message translates to:
  /// **'Pronouns'**
  String get lblPronouns;

  /// No description provided for @lblWhatShouldPeopleCallYou.
  ///
  /// In en, this message translates to:
  /// **'What should people call you?'**
  String get lblWhatShouldPeopleCallYou;

  /// No description provided for @lblNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get lblNever;

  /// No description provided for @lblSometimes.
  ///
  /// In en, this message translates to:
  /// **'Sometimes'**
  String get lblSometimes;

  /// No description provided for @lblYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get lblYes;

  /// No description provided for @lblSomethingCasual.
  ///
  /// In en, this message translates to:
  /// **'Something casual'**
  String get lblSomethingCasual;

  /// No description provided for @lblStillFiguringItOut.
  ///
  /// In en, this message translates to:
  /// **'Still figuring it out'**
  String get lblStillFiguringItOut;

  /// No description provided for @lblIMOpenToKids.
  ///
  /// In en, this message translates to:
  /// **'I\'m open to kids'**
  String get lblIMOpenToKids;

  /// No description provided for @lblIWantKids.
  ///
  /// In en, this message translates to:
  /// **'I want kids'**
  String get lblIWantKids;

  /// No description provided for @lblIDonTWantKids.
  ///
  /// In en, this message translates to:
  /// **'I don\'t want kids'**
  String get lblIDonTWantKids;

  /// No description provided for @lblHaveKids.
  ///
  /// In en, this message translates to:
  /// **'Have kids'**
  String get lblHaveKids;

  /// No description provided for @lblChristian.
  ///
  /// In en, this message translates to:
  /// **'Christian'**
  String get lblChristian;

  /// No description provided for @lblCatholic.
  ///
  /// In en, this message translates to:
  /// **'Catholic'**
  String get lblCatholic;

  /// No description provided for @lblProtestant.
  ///
  /// In en, this message translates to:
  /// **'Protestant'**
  String get lblProtestant;

  /// No description provided for @lblMuslim.
  ///
  /// In en, this message translates to:
  /// **'Muslim'**
  String get lblMuslim;

  /// No description provided for @lblJewish.
  ///
  /// In en, this message translates to:
  /// **'Jewish'**
  String get lblJewish;

  /// No description provided for @lblHindu.
  ///
  /// In en, this message translates to:
  /// **'Hindu'**
  String get lblHindu;

  /// No description provided for @lblBuddhist.
  ///
  /// In en, this message translates to:
  /// **'Buddhist'**
  String get lblBuddhist;

  /// No description provided for @lblAgnostic.
  ///
  /// In en, this message translates to:
  /// **'Agnostic'**
  String get lblAgnostic;

  /// No description provided for @lblAtheist.
  ///
  /// In en, this message translates to:
  /// **'Atheist'**
  String get lblAtheist;

  /// No description provided for @lblTaoist.
  ///
  /// In en, this message translates to:
  /// **'Taoist'**
  String get lblTaoist;

  /// No description provided for @lblBahai.
  ///
  /// In en, this message translates to:
  /// **'Bahai'**
  String get lblBahai;

  /// No description provided for @lblJain.
  ///
  /// In en, this message translates to:
  /// **'Jain'**
  String get lblJain;

  /// No description provided for @lblNewAge.
  ///
  /// In en, this message translates to:
  /// **'New Age'**
  String get lblNewAge;

  /// No description provided for @lblShinto.
  ///
  /// In en, this message translates to:
  /// **'Shinto'**
  String get lblShinto;

  /// No description provided for @lblSikh.
  ///
  /// In en, this message translates to:
  /// **'Sikh'**
  String get lblSikh;

  /// No description provided for @lblAnarchist.
  ///
  /// In en, this message translates to:
  /// **'Anarchist'**
  String get lblAnarchist;

  /// No description provided for @lblApolitical.
  ///
  /// In en, this message translates to:
  /// **'Apolitical'**
  String get lblApolitical;

  /// No description provided for @lblCentrist.
  ///
  /// In en, this message translates to:
  /// **'Centrist'**
  String get lblCentrist;

  /// No description provided for @lblCommunist.
  ///
  /// In en, this message translates to:
  /// **'Communist'**
  String get lblCommunist;

  /// No description provided for @lblConservative.
  ///
  /// In en, this message translates to:
  /// **'Conservative'**
  String get lblConservative;

  /// No description provided for @lblDemocratic.
  ///
  /// In en, this message translates to:
  /// **'Democratic'**
  String get lblDemocratic;

  /// No description provided for @lblFeminist.
  ///
  /// In en, this message translates to:
  /// **'Feminist'**
  String get lblFeminist;

  /// No description provided for @lblGlobalist.
  ///
  /// In en, this message translates to:
  /// **'Globalist'**
  String get lblGlobalist;

  /// No description provided for @lblGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get lblGreen;

  /// No description provided for @lblLabour.
  ///
  /// In en, this message translates to:
  /// **'Labour'**
  String get lblLabour;

  /// No description provided for @lblLeftLeaning.
  ///
  /// In en, this message translates to:
  /// **'Left-Leaning'**
  String get lblLeftLeaning;

  /// No description provided for @lblLiberal.
  ///
  /// In en, this message translates to:
  /// **'Liberal'**
  String get lblLiberal;

  /// No description provided for @lblLibertarian.
  ///
  /// In en, this message translates to:
  /// **'Libertarian'**
  String get lblLibertarian;

  /// No description provided for @lblNationalist.
  ///
  /// In en, this message translates to:
  /// **'Nationalist'**
  String get lblNationalist;

  /// No description provided for @lblProgressive.
  ///
  /// In en, this message translates to:
  /// **'Progressive'**
  String get lblProgressive;

  /// No description provided for @lblRepublican.
  ///
  /// In en, this message translates to:
  /// **'Republican'**
  String get lblRepublican;

  /// No description provided for @lblRightLeaning.
  ///
  /// In en, this message translates to:
  /// **'Right-Leaning'**
  String get lblRightLeaning;

  /// No description provided for @lblSocialist.
  ///
  /// In en, this message translates to:
  /// **'Socialist'**
  String get lblSocialist;

  /// No description provided for @lblStraight.
  ///
  /// In en, this message translates to:
  /// **'Straight'**
  String get lblStraight;

  /// No description provided for @lblGay.
  ///
  /// In en, this message translates to:
  /// **'Gay'**
  String get lblGay;

  /// No description provided for @lblLesbian.
  ///
  /// In en, this message translates to:
  /// **'Lesbian'**
  String get lblLesbian;

  /// No description provided for @lblBisexual.
  ///
  /// In en, this message translates to:
  /// **'Bisexual'**
  String get lblBisexual;

  /// No description provided for @lblAsexual.
  ///
  /// In en, this message translates to:
  /// **'Asexual'**
  String get lblAsexual;

  /// No description provided for @lblHeHim.
  ///
  /// In en, this message translates to:
  /// **'he/him'**
  String get lblHeHim;

  /// No description provided for @lblSheHer.
  ///
  /// In en, this message translates to:
  /// **'she/her'**
  String get lblSheHer;

  /// No description provided for @lblTheyThem.
  ///
  /// In en, this message translates to:
  /// **'they/them'**
  String get lblTheyThem;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @saveSelected.
  ///
  /// In en, this message translates to:
  /// **'Save {count} selected'**
  String saveSelected(int count);

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon.'**
  String get comingSoon;

  /// No description provided for @sectionMyPersonality.
  ///
  /// In en, this message translates to:
  /// **'My personality'**
  String get sectionMyPersonality;

  /// No description provided for @sectionMyBeliefs.
  ///
  /// In en, this message translates to:
  /// **'My beliefs and values'**
  String get sectionMyBeliefs;

  /// No description provided for @sectionMyHabits.
  ///
  /// In en, this message translates to:
  /// **'My habits'**
  String get sectionMyHabits;

  /// No description provided for @sectionMyRelationships.
  ///
  /// In en, this message translates to:
  /// **'What I want in my relationships'**
  String get sectionMyRelationships;

  /// No description provided for @sectionMyBackground.
  ///
  /// In en, this message translates to:
  /// **'My background'**
  String get sectionMyBackground;

  /// No description provided for @sectionWhoIAm.
  ///
  /// In en, this message translates to:
  /// **'Who I am'**
  String get sectionWhoIAm;

  /// No description provided for @bioTitle.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bioTitle;

  /// No description provided for @bioPrompt.
  ///
  /// In en, this message translates to:
  /// **'Tell people who you are.'**
  String get bioPrompt;

  /// No description provided for @education.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get education;

  /// No description provided for @university.
  ///
  /// In en, this message translates to:
  /// **'University'**
  String get university;

  /// No description provided for @universityNotDetected.
  ///
  /// In en, this message translates to:
  /// **'Not detected'**
  String get universityNotDetected;

  /// No description provided for @universityFromEmail.
  ///
  /// In en, this message translates to:
  /// **'Taken from your student email and cannot be changed.'**
  String get universityFromEmail;

  /// No description provided for @major.
  ///
  /// In en, this message translates to:
  /// **'Major/Program'**
  String get major;

  /// No description provided for @majorHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Applied Informatics'**
  String get majorHint;

  /// No description provided for @currentlyStudying.
  ///
  /// In en, this message translates to:
  /// **'I\'m currently studying'**
  String get currentlyStudying;

  /// No description provided for @occupation.
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get occupation;

  /// No description provided for @occupationAllOptional.
  ///
  /// In en, this message translates to:
  /// **'All optional - fill in whatever applies.'**
  String get occupationAllOptional;

  /// No description provided for @job.
  ///
  /// In en, this message translates to:
  /// **'Job'**
  String get job;

  /// No description provided for @jobHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Barista at a coffee shop'**
  String get jobHint;

  /// No description provided for @volunteering.
  ///
  /// In en, this message translates to:
  /// **'Volunteering'**
  String get volunteering;

  /// No description provided for @volunteeringHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Animal shelter every Sunday'**
  String get volunteeringHint;

  /// No description provided for @otherOccupation.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherOccupation;

  /// No description provided for @otherOccupationHint.
  ///
  /// In en, this message translates to:
  /// **'Anything else you do'**
  String get otherOccupationHint;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @locationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Where are you based?'**
  String get locationPrompt;

  /// No description provided for @locationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Thessaloniki'**
  String get locationHint;

  /// No description provided for @datePreferences.
  ///
  /// In en, this message translates to:
  /// **'Date Preferences'**
  String get datePreferences;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// No description provided for @aboutFoitiFinder.
  ///
  /// In en, this message translates to:
  /// **'About FoitiFinder'**
  String get aboutFoitiFinder;

  /// No description provided for @openSourceLicences.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get openSourceLicences;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @addStoryToPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a story to a photo'**
  String get addStoryToPhoto;

  /// No description provided for @sectionMyMusicTaste.
  ///
  /// In en, this message translates to:
  /// **'My music taste'**
  String get sectionMyMusicTaste;

  /// No description provided for @myTune.
  ///
  /// In en, this message translates to:
  /// **'My tune'**
  String get myTune;

  /// No description provided for @favouriteArtists.
  ///
  /// In en, this message translates to:
  /// **'Favourite artists'**
  String get favouriteArtists;

  /// No description provided for @languagesSpoken.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languagesSpoken;

  /// No description provided for @policies.
  ///
  /// In en, this message translates to:
  /// **'Policies'**
  String get policies;

  /// No description provided for @privacyStatement.
  ///
  /// In en, this message translates to:
  /// **'Privacy Statement'**
  String get privacyStatement;

  /// No description provided for @userTerms.
  ///
  /// In en, this message translates to:
  /// **'User Terms'**
  String get userTerms;

  /// No description provided for @userGuidelines.
  ///
  /// In en, this message translates to:
  /// **'User Guidelines'**
  String get userGuidelines;

  /// No description provided for @cancellationPolicy.
  ///
  /// In en, this message translates to:
  /// **'Cancellation Policy'**
  String get cancellationPolicy;

  /// No description provided for @recommenderSystem.
  ///
  /// In en, this message translates to:
  /// **'How our recommender system works'**
  String get recommenderSystem;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @photoStories.
  ///
  /// In en, this message translates to:
  /// **'Photo stories'**
  String get photoStories;

  /// No description provided for @photoStoriesIntro.
  ///
  /// In en, this message translates to:
  /// **'Tap a photo to tell the story behind it.'**
  String get photoStoriesIntro;

  /// No description provided for @noPhotosYet.
  ///
  /// In en, this message translates to:
  /// **'Add some photos first and their stories will show up here.'**
  String get noPhotosYet;

  /// No description provided for @addStory.
  ///
  /// In en, this message translates to:
  /// **'Add a story'**
  String get addStory;

  /// No description provided for @editStory.
  ///
  /// In en, this message translates to:
  /// **'Edit story'**
  String get editStory;

  /// No description provided for @storyHint.
  ///
  /// In en, this message translates to:
  /// **'What is happening in this photo?'**
  String get storyHint;

  /// No description provided for @removeStory.
  ///
  /// In en, this message translates to:
  /// **'Remove story'**
  String get removeStory;

  /// No description provided for @storySaved.
  ///
  /// In en, this message translates to:
  /// **'Story saved.'**
  String get storySaved;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @profilePicture.
  ///
  /// In en, this message translates to:
  /// **'Profile picture'**
  String get profilePicture;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @profilePictureNoStory.
  ///
  /// In en, this message translates to:
  /// **'Your profile picture does not get a story.'**
  String get profilePictureNoStory;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @birthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get birthday;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @placeOfResidence.
  ///
  /// In en, this message translates to:
  /// **'Place of residence'**
  String get placeOfResidence;

  /// No description provided for @prefAchaea.
  ///
  /// In en, this message translates to:
  /// **'Achaea'**
  String get prefAchaea;

  /// No description provided for @prefAetoliaAcarnania.
  ///
  /// In en, this message translates to:
  /// **'Aetolia-Acarnania'**
  String get prefAetoliaAcarnania;

  /// No description provided for @prefArcadia.
  ///
  /// In en, this message translates to:
  /// **'Arcadia'**
  String get prefArcadia;

  /// No description provided for @prefArgolis.
  ///
  /// In en, this message translates to:
  /// **'Argolis'**
  String get prefArgolis;

  /// No description provided for @prefArta.
  ///
  /// In en, this message translates to:
  /// **'Arta'**
  String get prefArta;

  /// No description provided for @prefAthens.
  ///
  /// In en, this message translates to:
  /// **'Athens'**
  String get prefAthens;

  /// No description provided for @prefBoeotia.
  ///
  /// In en, this message translates to:
  /// **'Boeotia'**
  String get prefBoeotia;

  /// No description provided for @prefCephalonia.
  ///
  /// In en, this message translates to:
  /// **'Cephalonia'**
  String get prefCephalonia;

  /// No description provided for @prefChalkidiki.
  ///
  /// In en, this message translates to:
  /// **'Chalkidiki'**
  String get prefChalkidiki;

  /// No description provided for @prefChania.
  ///
  /// In en, this message translates to:
  /// **'Chania'**
  String get prefChania;

  /// No description provided for @prefChios.
  ///
  /// In en, this message translates to:
  /// **'Chios'**
  String get prefChios;

  /// No description provided for @prefCorfu.
  ///
  /// In en, this message translates to:
  /// **'Corfu'**
  String get prefCorfu;

  /// No description provided for @prefCorinthia.
  ///
  /// In en, this message translates to:
  /// **'Corinthia'**
  String get prefCorinthia;

  /// No description provided for @prefCyclades.
  ///
  /// In en, this message translates to:
  /// **'Cyclades'**
  String get prefCyclades;

  /// No description provided for @prefDodecanese.
  ///
  /// In en, this message translates to:
  /// **'Dodecanese'**
  String get prefDodecanese;

  /// No description provided for @prefDrama.
  ///
  /// In en, this message translates to:
  /// **'Drama'**
  String get prefDrama;

  /// No description provided for @prefEastAttica.
  ///
  /// In en, this message translates to:
  /// **'East Attica'**
  String get prefEastAttica;

  /// No description provided for @prefElis.
  ///
  /// In en, this message translates to:
  /// **'Elis'**
  String get prefElis;

  /// No description provided for @prefEuboea.
  ///
  /// In en, this message translates to:
  /// **'Euboea'**
  String get prefEuboea;

  /// No description provided for @prefEvros.
  ///
  /// In en, this message translates to:
  /// **'Evros'**
  String get prefEvros;

  /// No description provided for @prefEvrytania.
  ///
  /// In en, this message translates to:
  /// **'Evrytania'**
  String get prefEvrytania;

  /// No description provided for @prefFlorina.
  ///
  /// In en, this message translates to:
  /// **'Florina'**
  String get prefFlorina;

  /// No description provided for @prefGrevena.
  ///
  /// In en, this message translates to:
  /// **'Grevena'**
  String get prefGrevena;

  /// No description provided for @prefHeraklion.
  ///
  /// In en, this message translates to:
  /// **'Heraklion'**
  String get prefHeraklion;

  /// No description provided for @prefImathia.
  ///
  /// In en, this message translates to:
  /// **'Imathia'**
  String get prefImathia;

  /// No description provided for @prefIoannina.
  ///
  /// In en, this message translates to:
  /// **'Ioannina'**
  String get prefIoannina;

  /// No description provided for @prefKarditsa.
  ///
  /// In en, this message translates to:
  /// **'Karditsa'**
  String get prefKarditsa;

  /// No description provided for @prefKastoria.
  ///
  /// In en, this message translates to:
  /// **'Kastoria'**
  String get prefKastoria;

  /// No description provided for @prefKavala.
  ///
  /// In en, this message translates to:
  /// **'Kavala'**
  String get prefKavala;

  /// No description provided for @prefKilkis.
  ///
  /// In en, this message translates to:
  /// **'Kilkis'**
  String get prefKilkis;

  /// No description provided for @prefKozani.
  ///
  /// In en, this message translates to:
  /// **'Kozani'**
  String get prefKozani;

  /// No description provided for @prefLaconia.
  ///
  /// In en, this message translates to:
  /// **'Laconia'**
  String get prefLaconia;

  /// No description provided for @prefLarissa.
  ///
  /// In en, this message translates to:
  /// **'Larissa'**
  String get prefLarissa;

  /// No description provided for @prefLasithi.
  ///
  /// In en, this message translates to:
  /// **'Lasithi'**
  String get prefLasithi;

  /// No description provided for @prefLefkada.
  ///
  /// In en, this message translates to:
  /// **'Lefkada'**
  String get prefLefkada;

  /// No description provided for @prefLesbos.
  ///
  /// In en, this message translates to:
  /// **'Lesbos'**
  String get prefLesbos;

  /// No description provided for @prefMagnesia.
  ///
  /// In en, this message translates to:
  /// **'Magnesia'**
  String get prefMagnesia;

  /// No description provided for @prefMessenia.
  ///
  /// In en, this message translates to:
  /// **'Messenia'**
  String get prefMessenia;

  /// No description provided for @prefPella.
  ///
  /// In en, this message translates to:
  /// **'Pella'**
  String get prefPella;

  /// No description provided for @prefPhocis.
  ///
  /// In en, this message translates to:
  /// **'Phocis'**
  String get prefPhocis;

  /// No description provided for @prefPhthiotis.
  ///
  /// In en, this message translates to:
  /// **'Phthiotis'**
  String get prefPhthiotis;

  /// No description provided for @prefPieria.
  ///
  /// In en, this message translates to:
  /// **'Pieria'**
  String get prefPieria;

  /// No description provided for @prefPiraeus.
  ///
  /// In en, this message translates to:
  /// **'Piraeus'**
  String get prefPiraeus;

  /// No description provided for @prefPreveza.
  ///
  /// In en, this message translates to:
  /// **'Preveza'**
  String get prefPreveza;

  /// No description provided for @prefRethymno.
  ///
  /// In en, this message translates to:
  /// **'Rethymno'**
  String get prefRethymno;

  /// No description provided for @prefRhodope.
  ///
  /// In en, this message translates to:
  /// **'Rhodope'**
  String get prefRhodope;

  /// No description provided for @prefSamos.
  ///
  /// In en, this message translates to:
  /// **'Samos'**
  String get prefSamos;

  /// No description provided for @prefSerres.
  ///
  /// In en, this message translates to:
  /// **'Serres'**
  String get prefSerres;

  /// No description provided for @prefThesprotia.
  ///
  /// In en, this message translates to:
  /// **'Thesprotia'**
  String get prefThesprotia;

  /// No description provided for @prefThessaloniki.
  ///
  /// In en, this message translates to:
  /// **'Thessaloniki'**
  String get prefThessaloniki;

  /// No description provided for @prefTrikala.
  ///
  /// In en, this message translates to:
  /// **'Trikala'**
  String get prefTrikala;

  /// No description provided for @prefWestAttica.
  ///
  /// In en, this message translates to:
  /// **'West Attica'**
  String get prefWestAttica;

  /// No description provided for @prefXanthi.
  ///
  /// In en, this message translates to:
  /// **'Xanthi'**
  String get prefXanthi;

  /// No description provided for @prefZakynthos.
  ///
  /// In en, this message translates to:
  /// **'Zakynthos'**
  String get prefZakynthos;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @man.
  ///
  /// In en, this message translates to:
  /// **'Man'**
  String get man;

  /// No description provided for @woman.
  ///
  /// In en, this message translates to:
  /// **'Woman'**
  String get woman;

  /// No description provided for @nonConforming.
  ///
  /// In en, this message translates to:
  /// **'Non-conforming'**
  String get nonConforming;

  /// No description provided for @cm.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get cm;

  /// No description provided for @invalidHeight.
  ///
  /// In en, this message translates to:
  /// **'Enter a height between {min} and {max} cm'**
  String invalidHeight(int min, int max);

  /// No description provided for @lblWhatDoYouWant.
  ///
  /// In en, this message translates to:
  /// **'What do you want?'**
  String get lblWhatDoYouWant;

  /// No description provided for @heightRange.
  ///
  /// In en, this message translates to:
  /// **'Height Range'**
  String get heightRange;

  /// No description provided for @showOutsideResidence.
  ///
  /// In en, this message translates to:
  /// **'Show people outside my place of residence'**
  String get showOutsideResidence;

  /// No description provided for @sectionTheirHabits.
  ///
  /// In en, this message translates to:
  /// **'Their habits'**
  String get sectionTheirHabits;

  /// No description provided for @sectionWhatTheyWant.
  ///
  /// In en, this message translates to:
  /// **'What they want'**
  String get sectionWhatTheyWant;

  /// No description provided for @pronounsIntro.
  ///
  /// In en, this message translates to:
  /// **'Here you can share your pronouns with other users. Sharing them is completely optional.'**
  String get pronounsIntro;

  /// No description provided for @pronounsCustom.
  ///
  /// In en, this message translates to:
  /// **'Pronoun description'**
  String get pronounsCustom;

  /// No description provided for @pronounsCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Your own wording'**
  String get pronounsCustomHint;

  /// No description provided for @pronounsCustomLocked.
  ///
  /// In en, this message translates to:
  /// **'Clear the selection above to write your own.'**
  String get pronounsCustomLocked;

  /// No description provided for @languagesIntro.
  ///
  /// In en, this message translates to:
  /// **'You will only see people that speak at least one common language.'**
  String get languagesIntro;

  /// No description provided for @lblGreek.
  ///
  /// In en, this message translates to:
  /// **'Greek'**
  String get lblGreek;

  /// No description provided for @lblEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get lblEnglish;

  /// No description provided for @lblAlbanian.
  ///
  /// In en, this message translates to:
  /// **'Albanian'**
  String get lblAlbanian;

  /// No description provided for @lblArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get lblArabic;

  /// No description provided for @lblBulgarian.
  ///
  /// In en, this message translates to:
  /// **'Bulgarian'**
  String get lblBulgarian;

  /// No description provided for @lblChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get lblChinese;

  /// No description provided for @lblFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get lblFrench;

  /// No description provided for @lblGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get lblGerman;

  /// No description provided for @lblItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get lblItalian;

  /// No description provided for @lblRomanian.
  ///
  /// In en, this message translates to:
  /// **'Romanian'**
  String get lblRomanian;

  /// No description provided for @lblRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get lblRussian;

  /// No description provided for @lblSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get lblSpanish;

  /// No description provided for @lblTurkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get lblTurkish;

  /// No description provided for @lblUkrainian.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get lblUkrainian;

  /// No description provided for @lblGreekSignLanguage.
  ///
  /// In en, this message translates to:
  /// **'Greek Sign Language'**
  String get lblGreekSignLanguage;

  /// No description provided for @tabEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get tabEdit;

  /// No description provided for @tabView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get tabView;

  /// No description provided for @profilePreviewSoon.
  ///
  /// In en, this message translates to:
  /// **'Your profile, as other people see it.'**
  String get profilePreviewSoon;

  /// No description provided for @preferredLanguagesIntro.
  ///
  /// In en, this message translates to:
  /// **'You will only be shown people that speak at least one of your selected languages.'**
  String get preferredLanguagesIntro;

  /// No description provided for @reportUser.
  ///
  /// In en, this message translates to:
  /// **'Report this profile'**
  String get reportUser;

  /// No description provided for @addAtLeastPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add at least {count} photos to continue'**
  String addAtLeastPhotos(int count);

  /// No description provided for @lblSomethingSerious.
  ///
  /// In en, this message translates to:
  /// **'Something serious'**
  String get lblSomethingSerious;

  /// No description provided for @instagramTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Instagram'**
  String get instagramTitle;

  /// No description provided for @instagramIntro.
  ///
  /// In en, this message translates to:
  /// **'FoitiFinder has no chat. When you and someone else both say yes to a match, you swap Instagram usernames and carry on there.'**
  String get instagramIntro;

  /// No description provided for @instagramPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Nobody can see it by browsing. It is shown only to a person you have matched with, after you have both confirmed it.'**
  String get instagramPrivacy;

  /// No description provided for @instagramLabel.
  ///
  /// In en, this message translates to:
  /// **'Instagram username'**
  String get instagramLabel;

  /// No description provided for @instagramHint.
  ///
  /// In en, this message translates to:
  /// **'your.username'**
  String get instagramHint;

  /// No description provided for @instagramPasteOk.
  ///
  /// In en, this message translates to:
  /// **'You can paste a link to your profile, we will sort it out.'**
  String get instagramPasteOk;

  /// No description provided for @instagramInvalid.
  ///
  /// In en, this message translates to:
  /// **'That does not look like an Instagram username. Letters, numbers, full stops and underscores only.'**
  String get instagramInvalid;

  /// No description provided for @instagramRequiredNote.
  ///
  /// In en, this message translates to:
  /// **'Required, because without it a match has no way to continue.'**
  String get instagramRequiredNote;

  /// No description provided for @instagram.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get instagram;

  /// No description provided for @matchTitle.
  ///
  /// In en, this message translates to:
  /// **'It\'s a match'**
  String get matchTitle;

  /// No description provided for @matchBothLiked.
  ///
  /// In en, this message translates to:
  /// **'You and {name} liked each other.'**
  String matchBothLiked(String name);

  /// No description provided for @matchHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'FoitiFinder has no chat, so this carries on in your DMs. Share your Instagram and, if {name} says yes too, you will each get the other\'s username.'**
  String matchHowItWorks(String name);

  /// No description provided for @matchShare.
  ///
  /// In en, this message translates to:
  /// **'Share my Instagram'**
  String get matchShare;

  /// No description provided for @matchDecline.
  ///
  /// In en, this message translates to:
  /// **'Not interested'**
  String get matchDecline;

  /// No description provided for @matchViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View full profile'**
  String get matchViewProfile;

  /// No description provided for @matchConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Share your Instagram?'**
  String get matchConfirmTitle;

  /// No description provided for @matchConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will see @{handle} if they say yes too. This cannot be taken back.'**
  String matchConfirmBody(String name, String handle);

  /// No description provided for @matchConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Yes, share it'**
  String get matchConfirmAction;

  /// No description provided for @matchWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name}'**
  String matchWaitingTitle(String name);

  /// No description provided for @matchWaitingBody.
  ///
  /// In en, this message translates to:
  /// **'You said yes. If {name} does too, you will get their username and they will get yours.'**
  String matchWaitingBody(String name);

  /// No description provided for @matchDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get matchDone;

  /// No description provided for @matchRevealedTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re connected'**
  String get matchRevealedTitle;

  /// No description provided for @matchCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get matchCopy;

  /// No description provided for @matchCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get matchCopied;

  /// No description provided for @matchOpenInstagram.
  ///
  /// In en, this message translates to:
  /// **'Open Instagram'**
  String get matchOpenInstagram;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Matches and answers show up on this page.'**
  String get noNotifications;

  /// No description provided for @notifMatchWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} matched with you'**
  String notifMatchWaitingTitle(String name);

  /// No description provided for @notifMatchWaitingBody.
  ///
  /// In en, this message translates to:
  /// **'They have already said yes. Tap to decide whether to share your Instagram.'**
  String get notifMatchWaitingBody;

  /// No description provided for @notifMatchRevealedTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re connected with {name}'**
  String notifMatchRevealedTitle(String name);

  /// No description provided for @notifMatchRevealedBody.
  ///
  /// In en, this message translates to:
  /// **'You both said yes. Tap to see their Instagram.'**
  String get notifMatchRevealedBody;

  /// No description provided for @notifMatchDeclinedTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} didn\'t go ahead'**
  String notifMatchDeclinedTitle(String name);

  /// No description provided for @notifMatchDeclinedBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing was shared. Plenty more out there.'**
  String get notifMatchDeclinedBody;

  /// No description provided for @notifSomeone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get notifSomeone;

  /// No description provided for @notifJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get notifJustNow;

  /// No description provided for @notifMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String notifMinutesAgo(int count);

  /// No description provided for @notifHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String notifHoursAgo(int count);

  /// No description provided for @notifDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String notifDaysAgo(int count);

  /// No description provided for @matchTheirTurn.
  ///
  /// In en, this message translates to:
  /// **'{name} said yes'**
  String matchTheirTurn(String name);

  /// No description provided for @swipeQueued.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Your like is saved and will be sent as soon as you are back online.'**
  String get swipeQueued;

  /// No description provided for @notifMatchOwnBody.
  ///
  /// In en, this message translates to:
  /// **'Tap to finish sharing your Instagram.'**
  String get notifMatchOwnBody;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches yet. Keep swiping — when someone likes you back they will show up here.'**
  String get noMatches;

  /// No description provided for @matchYourTurn.
  ///
  /// In en, this message translates to:
  /// **'Your turn'**
  String get matchYourTurn;

  /// Title for YOUR OWN pending match - the one you completed by liking back. notifMatchWaitingTitle reads 'X matched with you', which is backwards for this side.
  ///
  /// In en, this message translates to:
  /// **'You matched with {name}'**
  String notifMatchOwnTitle(String name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['el', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'el':
      return AppLocalizationsEl();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
