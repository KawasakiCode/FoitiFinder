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

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get account;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @phoneVerified.
  ///
  /// In en, this message translates to:
  /// **'Phone Number Verified'**
  String get phoneVerified;

  /// No description provided for @phoneNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Unverified Phone Number'**
  String get phoneNotVerified;

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

  /// No description provided for @outOfRange1.
  ///
  /// In en, this message translates to:
  /// **'Show people out of range'**
  String get outOfRange1;

  /// No description provided for @outOfRange2.
  ///
  /// In en, this message translates to:
  /// **'if I run out of profiles to see'**
  String get outOfRange2;

  /// No description provided for @balanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced Recommendations'**
  String get balanced;

  /// No description provided for @balancedText.
  ///
  /// In en, this message translates to:
  /// **'See the most relevant people to you'**
  String get balancedText;

  /// No description provided for @recentlyActive.
  ///
  /// In en, this message translates to:
  /// **'Recently Active'**
  String get recentlyActive;

  /// No description provided for @recentlyActiveText.
  ///
  /// In en, this message translates to:
  /// **'See the most recently active people first'**
  String get recentlyActiveText;

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

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

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

  /// No description provided for @exploreText.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Explore'**
  String get exploreText;

  /// No description provided for @similarPlans.
  ///
  /// In en, this message translates to:
  /// **'Similar plans and lifestyles'**
  String get similarPlans;

  /// No description provided for @similarPlansText.
  ///
  /// In en, this message translates to:
  /// **'Find people with similar life goals and hobbies'**
  String get similarPlansText;

  /// No description provided for @newMatches.
  ///
  /// In en, this message translates to:
  /// **'New Matches'**
  String get newMatches;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @phoneNumberSettings.
  ///
  /// In en, this message translates to:
  /// **'Phone Number Settings'**
  String get phoneNumberSettings;

  /// No description provided for @phoneNumberPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter Phone Number'**
  String get phoneNumberPlaceholder;

  /// No description provided for @updatePhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Update My Phone Number'**
  String get updatePhoneNumber;

  /// No description provided for @snackbarNonValidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number 69xxxxxxxx'**
  String get snackbarNonValidPhoneNumber;

  /// No description provided for @snackbarVerified.
  ///
  /// In en, this message translates to:
  /// **'Phone Verified'**
  String get snackbarVerified;

  /// No description provided for @snackbarCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'Code expired'**
  String get snackbarCodeExpired;

  /// No description provided for @snackbarVerifyFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to verify phone number'**
  String get snackbarVerifyFailed;

  /// No description provided for @verifyPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone Number'**
  String get verifyPhoneNumber;

  /// No description provided for @enterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code sent to your phone number'**
  String get enterCode;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @codeLessThan6.
  ///
  /// In en, this message translates to:
  /// **'Enter the full 6-digit code'**
  String get codeLessThan6;

  /// No description provided for @invalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code or an error occured. Please try again'**
  String get invalidCode;

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

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted. Please sign up again and verify your email.'**
  String get accountDeleted;

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

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

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

  /// No description provided for @signUpToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign Up to continue'**
  String get signUpToContinue;

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

  /// No description provided for @cannotRewind.
  ///
  /// In en, this message translates to:
  /// **'Cannot rewind further'**
  String get cannotRewind;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @verifySend.
  ///
  /// In en, this message translates to:
  /// **'Verification sent to '**
  String get verifySend;

  /// No description provided for @checkInbox.
  ///
  /// In en, this message translates to:
  /// **'Please check your inbox to finish updating your email.'**
  String get checkInbox;

  /// No description provided for @failedVerifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Failed to send verification: '**
  String get failedVerifyEmail;

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

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'To change your email, please confirm your current password.'**
  String get confirmPassword;

  /// No description provided for @securityCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Security check failed: '**
  String get securityCheckFailed;

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

  /// No description provided for @noInternet.
  ///
  /// In en, this message translates to:
  /// **'No Internet Connectiion'**
  String get noInternet;

  /// No description provided for @turnOnWifi.
  ///
  /// In en, this message translates to:
  /// **'Please turn on Wifi or Mobile Data to continue'**
  String get turnOnWifi;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

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

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message...'**
  String get message;

  /// No description provided for @failedToSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message'**
  String get failedToSendMessage;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'You have no new matches'**
  String get noMatches;

  /// No description provided for @noMessages.
  ///
  /// In en, this message translates to:
  /// **'You have no messages yet'**
  String get noMessages;

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

  /// No description provided for @enterOtpCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the full 6-digit code'**
  String get enterOtpCode;

  /// No description provided for @invalidOtpCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code or an error occured. Please try again'**
  String get invalidOtpCode;

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

  /// No description provided for @noWifi.
  ///
  /// In en, this message translates to:
  /// **'No Internet Connectiion'**
  String get noWifi;

  /// No description provided for @turnWifiOn.
  ///
  /// In en, this message translates to:
  /// **'Please turn on Wifi or Mobile Data to continue'**
  String get turnWifiOn;

  /// No description provided for @verifyYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get verifyYourEmail;

  /// No description provided for @verifyyourEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyyourEmail;

  /// No description provided for @backToSettings.
  ///
  /// In en, this message translates to:
  /// **'Back to settings'**
  String get backToSettings;

  /// No description provided for @mailAlreadyVerified.
  ///
  /// In en, this message translates to:
  /// **'Your email is already verified'**
  String get mailAlreadyVerified;
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
