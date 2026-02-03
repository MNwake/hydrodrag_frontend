import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'HydroDrags'**
  String get appTitle;

  /// Short tagline for the app
  ///
  /// In en, this message translates to:
  /// **'Racer Registration & Event Management'**
  String get appTagline;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get spanish;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @continueAs.
  ///
  /// In en, this message translates to:
  /// **'Continue as'**
  String get continueAs;

  /// Label for racer
  ///
  /// In en, this message translates to:
  /// **'Racer'**
  String get racer;

  /// No description provided for @adminStaff.
  ///
  /// In en, this message translates to:
  /// **'Admin / Staff'**
  String get adminStaff;

  /// No description provided for @spectator.
  ///
  /// In en, this message translates to:
  /// **'Spectator'**
  String get spectator;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get sendCode;

  /// No description provided for @sendCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a verification code to your email'**
  String get sendCodeSubtitle;

  /// No description provided for @codeSent.
  ///
  /// In en, this message translates to:
  /// **'Code sent! Check your email'**
  String get codeSent;

  /// No description provided for @enterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter Verification Code'**
  String get enterCode;

  /// No description provided for @enterCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to your email'**
  String get enterCodeSubtitle;

  /// No description provided for @codeRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the verification code'**
  String get codeRequired;

  /// No description provided for @invalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code. Please try again'**
  String get invalidCode;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @didntReceiveCode.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive a code?'**
  String get didntReceiveCode;

  /// No description provided for @codeExpired.
  ///
  /// In en, this message translates to:
  /// **'Code expired. Please request a new one'**
  String get codeExpired;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @verifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get verifying;

  /// No description provided for @sendingCode.
  ///
  /// In en, this message translates to:
  /// **'Sending code...'**
  String get sendingCode;

  /// No description provided for @racerProfile.
  ///
  /// In en, this message translates to:
  /// **'Racer Profile'**
  String get racerProfile;

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInfo;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @genderOptional.
  ///
  /// In en, this message translates to:
  /// **'Gender (Optional)'**
  String get genderOptional;

  /// No description provided for @nationality.
  ///
  /// In en, this message translates to:
  /// **'Nationality'**
  String get nationality;

  /// No description provided for @nationalityOptional.
  ///
  /// In en, this message translates to:
  /// **'Nationality (Optional)'**
  String get nationalityOptional;

  /// No description provided for @contactInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact Information'**
  String get contactInfo;

  /// No description provided for @emergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contact'**
  String get emergencyContact;

  /// No description provided for @emergencyContactName.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contact Name'**
  String get emergencyContactName;

  /// No description provided for @emergencyContactPhone.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contact Phone'**
  String get emergencyContactPhone;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @street.
  ///
  /// In en, this message translates to:
  /// **'Street'**
  String get street;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @stateProvince.
  ///
  /// In en, this message translates to:
  /// **'State / Province'**
  String get stateProvince;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @zipPostalCode.
  ///
  /// In en, this message translates to:
  /// **'ZIP / Postal Code'**
  String get zipPostalCode;

  /// No description provided for @membershipDetails.
  ///
  /// In en, this message translates to:
  /// **'Membership Details'**
  String get membershipDetails;

  /// No description provided for @ihraMembership.
  ///
  /// In en, this message translates to:
  /// **'IHRA Membership'**
  String get ihraMembership;

  /// No description provided for @organization.
  ///
  /// In en, this message translates to:
  /// **'Organization / Association'**
  String get organization;

  /// No description provided for @membershipNumber.
  ///
  /// In en, this message translates to:
  /// **'Membership Number'**
  String get membershipNumber;

  /// No description provided for @membershipNumberOptional.
  ///
  /// In en, this message translates to:
  /// **'Membership Number (Optional)'**
  String get membershipNumberOptional;

  /// No description provided for @ihraMembershipNumberOptional.
  ///
  /// In en, this message translates to:
  /// **'IHRA Membership # (Optional)'**
  String get ihraMembershipNumberOptional;

  /// No description provided for @ihraMembershipPurchasedAtOptional.
  ///
  /// In en, this message translates to:
  /// **'IHRA Membership Purchased At (Optional)'**
  String get ihraMembershipPurchasedAtOptional;

  /// No description provided for @classCategory.
  ///
  /// In en, this message translates to:
  /// **'Class / Category'**
  String get classCategory;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editName.
  ///
  /// In en, this message translates to:
  /// **'Edit Name'**
  String get editName;

  /// No description provided for @editPhone.
  ///
  /// In en, this message translates to:
  /// **'Edit Phone'**
  String get editPhone;

  /// No description provided for @profileImageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile image updated'**
  String get profileImageUpdated;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @bioHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself...'**
  String get bioHint;

  /// No description provided for @editBio.
  ///
  /// In en, this message translates to:
  /// **'Edit Bio'**
  String get editBio;

  /// No description provided for @sponsors.
  ///
  /// In en, this message translates to:
  /// **'Sponsors'**
  String get sponsors;

  /// No description provided for @sponsorsHint.
  ///
  /// In en, this message translates to:
  /// **'List your sponsors (one per line)'**
  String get sponsorsHint;

  /// No description provided for @editSponsors.
  ///
  /// In en, this message translates to:
  /// **'Edit Sponsors'**
  String get editSponsors;

  /// No description provided for @banner.
  ///
  /// In en, this message translates to:
  /// **'Banner'**
  String get banner;

  /// No description provided for @editBanner.
  ///
  /// In en, this message translates to:
  /// **'Edit Banner'**
  String get editBanner;

  /// No description provided for @removeBanner.
  ///
  /// In en, this message translates to:
  /// **'Remove Banner'**
  String get removeBanner;

  /// No description provided for @bannerImageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Banner image updated'**
  String get bannerImageUpdated;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @activeEvents.
  ///
  /// In en, this message translates to:
  /// **'Active Events'**
  String get activeEvents;

  /// No description provided for @eventName.
  ///
  /// In en, this message translates to:
  /// **'Event Name'**
  String get eventName;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @registrationStatus.
  ///
  /// In en, this message translates to:
  /// **'Registration Status'**
  String get registrationStatus;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @registerForEvent.
  ///
  /// In en, this message translates to:
  /// **'Register for Event'**
  String get registerForEvent;

  /// No description provided for @eventRegistration.
  ///
  /// In en, this message translates to:
  /// **'Event Registration'**
  String get eventRegistration;

  /// No description provided for @vehicleCraftInfo.
  ///
  /// In en, this message translates to:
  /// **'Vehicle / Craft Information'**
  String get vehicleCraftInfo;

  /// No description provided for @craftType.
  ///
  /// In en, this message translates to:
  /// **'Craft Type'**
  String get craftType;

  /// No description provided for @make.
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get make;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @engineClass.
  ///
  /// In en, this message translates to:
  /// **'Engine Class'**
  String get engineClass;

  /// No description provided for @modifications.
  ///
  /// In en, this message translates to:
  /// **'Modifications'**
  String get modifications;

  /// No description provided for @classSelection.
  ///
  /// In en, this message translates to:
  /// **'Class Selection'**
  String get classSelection;

  /// No description provided for @raceOptions.
  ///
  /// In en, this message translates to:
  /// **'Race Options'**
  String get raceOptions;

  /// No description provided for @numberOfEntries.
  ///
  /// In en, this message translates to:
  /// **'Number of Entries'**
  String get numberOfEntries;

  /// No description provided for @heatPreferences.
  ///
  /// In en, this message translates to:
  /// **'Heat Preferences'**
  String get heatPreferences;

  /// Label for transponder ID field
  ///
  /// In en, this message translates to:
  /// **'Transponder ID'**
  String get transponderId;

  /// No description provided for @reviewConfirm.
  ///
  /// In en, this message translates to:
  /// **'Review & Confirm'**
  String get reviewConfirm;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @waiver.
  ///
  /// In en, this message translates to:
  /// **'Liability Waiver'**
  String get waiver;

  /// No description provided for @waiverExplanation.
  ///
  /// In en, this message translates to:
  /// **'This waiver must be reviewed and accepted before participation.'**
  String get waiverExplanation;

  /// No description provided for @viewWaiver.
  ///
  /// In en, this message translates to:
  /// **'View Waiver'**
  String get viewWaiver;

  /// No description provided for @downloadPdf.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get downloadPdf;

  /// No description provided for @iUnderstand.
  ///
  /// In en, this message translates to:
  /// **'I Understand'**
  String get iUnderstand;

  /// No description provided for @waiverSignature.
  ///
  /// In en, this message translates to:
  /// **'Waiver Signature'**
  String get waiverSignature;

  /// No description provided for @fullLegalName.
  ///
  /// In en, this message translates to:
  /// **'Full Legal Name'**
  String get fullLegalName;

  /// No description provided for @certifyAgree.
  ///
  /// In en, this message translates to:
  /// **'I certify that I have read and agree to the terms and conditions of this waiver.'**
  String get certifyAgree;

  /// No description provided for @signature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get signature;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @registrationComplete.
  ///
  /// In en, this message translates to:
  /// **'Registration Complete'**
  String get registrationComplete;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @registrationId.
  ///
  /// In en, this message translates to:
  /// **'Registration ID'**
  String get registrationId;

  /// No description provided for @waiverStatus.
  ///
  /// In en, this message translates to:
  /// **'Waiver Status'**
  String get waiverStatus;

  /// No description provided for @signed.
  ///
  /// In en, this message translates to:
  /// **'Signed'**
  String get signed;

  /// No description provided for @viewRegistration.
  ///
  /// In en, this message translates to:
  /// **'View Registration'**
  String get viewRegistration;

  /// No description provided for @downloadWaiverPdf.
  ///
  /// In en, this message translates to:
  /// **'Download Waiver PDF'**
  String get downloadWaiverPdf;

  /// No description provided for @returnToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Return to Event Dashboard'**
  String get returnToDashboard;

  /// No description provided for @racerDashboard.
  ///
  /// In en, this message translates to:
  /// **'My Event Dashboard'**
  String get racerDashboard;

  /// No description provided for @backToEvents.
  ///
  /// In en, this message translates to:
  /// **'Back to Events'**
  String get backToEvents;

  /// No description provided for @classVehicleSummary.
  ///
  /// In en, this message translates to:
  /// **'Class & Vehicle Summary'**
  String get classVehicleSummary;

  /// No description provided for @heatAssignments.
  ///
  /// In en, this message translates to:
  /// **'Heat Assignments'**
  String get heatAssignments;

  /// No description provided for @bracketPosition.
  ///
  /// In en, this message translates to:
  /// **'Bracket Position'**
  String get bracketPosition;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @scrollToEnd.
  ///
  /// In en, this message translates to:
  /// **'Please scroll to the end of the waiver to continue'**
  String get scrollToEnd;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Racer Sign In'**
  String get signIn;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to receive a verification code'**
  String get signInSubtitle;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get emailHint;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address'**
  String get emailRequired;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get invalidEmail;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @continueAsSpectator.
  ///
  /// In en, this message translates to:
  /// **'Continue as Spectator'**
  String get continueAsSpectator;

  /// No description provided for @viewEventsWithoutAccount.
  ///
  /// In en, this message translates to:
  /// **'View events without an account'**
  String get viewEventsWithoutAccount;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @signUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your racer account'**
  String get signUpSubtitle;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get confirmPasswordHint;

  /// No description provided for @confirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get confirmPasswordRequired;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @signInHere.
  ///
  /// In en, this message translates to:
  /// **'Sign in here'**
  String get signInHere;

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccountButton;

  /// Title for the info tab screen
  ///
  /// In en, this message translates to:
  /// **'HydroDrags Info'**
  String get hydrodragsInfo;

  /// Main event title displayed in hero section
  ///
  /// In en, this message translates to:
  /// **'2026 Fueltech US Nationals World Championships'**
  String get eventTitle2026;

  /// Event tagline
  ///
  /// In en, this message translates to:
  /// **'It\'s Time To Send It'**
  String get itsTimeToSendIt;

  /// About section title
  ///
  /// In en, this message translates to:
  /// **'About HydroDrags'**
  String get aboutHydrodrags;

  /// First paragraph of about section
  ///
  /// In en, this message translates to:
  /// **'The event features the World\'s fastest PWC Drag Racers, that come from all over the USA and beyond! This event has produced World Speed Records in every Class, With Speeds of 143mph in the Unlimited Class. The Stock and Spec Classes and our newest class Turbo No Nitrous are featured on Saturday, and the Superstock and Unlimited Classes and Speed Ally are featured on Sunday.'**
  String get aboutParagraph1;

  /// Second paragraph of about section
  ///
  /// In en, this message translates to:
  /// **'This is a fun event, filled with excitement and the adrenalin filled atmosphere providing some exciting racing, that also serves as an economic impact, with most of the competitors and their families, sponsors, and support crews coming from out of the area.'**
  String get aboutParagraph2;

  /// World record speed info card title
  ///
  /// In en, this message translates to:
  /// **'World Record Speed'**
  String get worldRecordSpeed;

  /// World record speed description
  ///
  /// In en, this message translates to:
  /// **'The FASTEST ski on the water is held by Team CRT With The Worlds Fastest Unlimited Ski of 143mph!'**
  String get worldRecordDescription;

  /// Age requirement info card title
  ///
  /// In en, this message translates to:
  /// **'Age Requirement'**
  String get ageRequirement;

  /// Age requirement description
  ///
  /// In en, this message translates to:
  /// **'We love seeing young riders get interested in the event but the earliest you can compete with the big boys is 15 years old.'**
  String get ageRequirementDescription;

  /// ISJBA membership info card title
  ///
  /// In en, this message translates to:
  /// **'ISJBA Membership Required'**
  String get isjbaMembershipRequired;

  /// ISJBA membership description
  ///
  /// In en, this message translates to:
  /// **'All competitors must have a valid ISJBA membership at the time of the event.'**
  String get isjbaMembershipDescription;

  /// Location and venue section title
  ///
  /// In en, this message translates to:
  /// **'Location & Venue'**
  String get locationVenue;

  /// Main venue name
  ///
  /// In en, this message translates to:
  /// **'Burt Aaronson South County Regional Park'**
  String get venueName;

  /// Venue subtitle/amphitheater name
  ///
  /// In en, this message translates to:
  /// **'Sunset Cove Amphitheater'**
  String get venueSubtitle;

  /// Full venue address
  ///
  /// In en, this message translates to:
  /// **'20405 Amphitheater Cir, Boca Raton, FL 33498'**
  String get venueAddress;

  /// Venue detail about seating
  ///
  /// In en, this message translates to:
  /// **'No bleacher seating - bring your own chairs and tents'**
  String get venueDetailNoBleachers;

  /// Venue detail about early arrival
  ///
  /// In en, this message translates to:
  /// **'Early arrival recommended to secure your spot'**
  String get venueDetailEarlyArrival;

  /// Venue detail about glass bottles
  ///
  /// In en, this message translates to:
  /// **'No glass bottles allowed'**
  String get venueDetailNoGlass;

  /// Venue detail about parking
  ///
  /// In en, this message translates to:
  /// **'Free spectator parking'**
  String get venueDetailFreeParking;

  /// Rules and regulations section title
  ///
  /// In en, this message translates to:
  /// **'Rules & Regulations'**
  String get rulesRegulations;

  /// Introduction text for rules section
  ///
  /// In en, this message translates to:
  /// **'We want to see new world records, but it is our priority to make sure everyone stays safe on a level playing field.'**
  String get rulesIntro;

  /// Key rules info card title
  ///
  /// In en, this message translates to:
  /// **'Key Rules'**
  String get keyRules;

  /// List of key rules
  ///
  /// In en, this message translates to:
  /// **'• NO SWITCHING OF PWC PERIOD! YOU RACE WHAT YOU REGISTER WITH.\n• Top 4 Skis Must Report within 5 Min To Tech Tent Following Their Race\n• 2 MIN COUNTDOWN From When Racer\'s name is Called over PA To Launchpad\n• Any Unsportsmanlike Conduct Will not be Tolerated\n• Anytime On the Water: Helmets and Life Jackets Required'**
  String get keyRulesDescription;

  /// Button text to view full rules
  ///
  /// In en, this message translates to:
  /// **'View Full Rules & Regulations'**
  String get viewFullRules;

  /// Sponsors section title
  ///
  /// In en, this message translates to:
  /// **'Our Sponsors'**
  String get ourSponsors;

  /// Introduction text for sponsors section
  ///
  /// In en, this message translates to:
  /// **'The HydroDrags US Nationals World Championship could not be possible without these sponsors.'**
  String get sponsorsIntro;

  /// No description provided for @sponsorFuelTech.
  ///
  /// In en, this message translates to:
  /// **'FuelTech'**
  String get sponsorFuelTech;

  /// No description provided for @sponsorFloridaSkiRiders.
  ///
  /// In en, this message translates to:
  /// **'Florida Ski Riders'**
  String get sponsorFloridaSkiRiders;

  /// No description provided for @sponsorRacerH2O.
  ///
  /// In en, this message translates to:
  /// **'Racer H2O'**
  String get sponsorRacerH2O;

  /// No description provided for @sponsorBrowardMotorsports.
  ///
  /// In en, this message translates to:
  /// **'Broward Motorsports'**
  String get sponsorBrowardMotorsports;

  /// No description provided for @sponsorAngelicaRacing.
  ///
  /// In en, this message translates to:
  /// **'Angelica Racing'**
  String get sponsorAngelicaRacing;

  /// No description provided for @sponsorFizzleRacing.
  ///
  /// In en, this message translates to:
  /// **'Fizzle Racing'**
  String get sponsorFizzleRacing;

  /// No description provided for @sponsorJLPerformance.
  ///
  /// In en, this message translates to:
  /// **'JL Performance'**
  String get sponsorJLPerformance;

  /// No description provided for @sponsorHydroTurf.
  ///
  /// In en, this message translates to:
  /// **'Hydro-Turf'**
  String get sponsorHydroTurf;

  /// No description provided for @sponsorRivaRacing.
  ///
  /// In en, this message translates to:
  /// **'Riva Racing'**
  String get sponsorRivaRacing;

  /// No description provided for @sponsorProVRacing.
  ///
  /// In en, this message translates to:
  /// **'Pro V Racing'**
  String get sponsorProVRacing;

  /// No description provided for @sponsorJetTribeRacing.
  ///
  /// In en, this message translates to:
  /// **'Jet Tribe Racing'**
  String get sponsorJetTribeRacing;

  /// No description provided for @sponsorISJBA.
  ///
  /// In en, this message translates to:
  /// **'ISJBA'**
  String get sponsorISJBA;

  /// Media partners section title
  ///
  /// In en, this message translates to:
  /// **'Media Partners'**
  String get mediaPartners;

  /// Introduction text for media partners section
  ///
  /// In en, this message translates to:
  /// **'Catch all the action through our media partners!'**
  String get mediaPartnersIntro;

  /// Media partner name
  ///
  /// In en, this message translates to:
  /// **'RACER H2O'**
  String get mediaRacerH2O;

  /// RACER H2O description
  ///
  /// In en, this message translates to:
  /// **'Live streaming coverage bringing you watercraft racing coverage like no one else.'**
  String get mediaRacerH2ODescription;

  /// Media partner name
  ///
  /// In en, this message translates to:
  /// **'Florida Ski Riders'**
  String get mediaFloridaSkiRiders;

  /// Florida Ski Riders description
  ///
  /// In en, this message translates to:
  /// **'Creating videos and capturing images and memories of the event.'**
  String get mediaFloridaSkiRidersDescription;

  /// Media partner name
  ///
  /// In en, this message translates to:
  /// **'MVP Productions'**
  String get mediaMVPProductions;

  /// MVP Productions description
  ///
  /// In en, this message translates to:
  /// **'Professional photography capturing life\'s best moments.'**
  String get mediaMVPProductionsDescription;

  /// Media partner name
  ///
  /// In en, this message translates to:
  /// **'Pro Rider Magazine'**
  String get mediaProRiderMagazine;

  /// Pro Rider Magazine description
  ///
  /// In en, this message translates to:
  /// **'Written articles and amazing images in the magazine that started it all.'**
  String get mediaProRiderMagazineDescription;

  /// Contact section title
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// Phone contact label
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get contactPhone;

  /// Contact phone number
  ///
  /// In en, this message translates to:
  /// **'(863) 409-8780'**
  String get contactPhoneNumber;

  /// Email contact label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get contactEmail;

  /// Contact email address
  ///
  /// In en, this message translates to:
  /// **'hydrodragsfl@gmail.com'**
  String get contactEmailAddress;

  /// Option to choose image from gallery
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// Option to take a photo with camera
  ///
  /// In en, this message translates to:
  /// **'Take a Photo'**
  String get takeAPhoto;

  /// Option to remove selected photo
  ///
  /// In en, this message translates to:
  /// **'Remove Photo'**
  String get removePhoto;

  /// Button to change profile photo
  ///
  /// In en, this message translates to:
  /// **'Change Photo'**
  String get changePhoto;

  /// Button to add profile photo
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get addPhoto;

  /// Placeholder text for date picker
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// Male gender option
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// Female gender option
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// Phone number input hint/placeholder
  ///
  /// In en, this message translates to:
  /// **'(555) 123-4567'**
  String get phoneHint;

  /// Button text to complete profile
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// Error message when image picker fails
  ///
  /// In en, this message translates to:
  /// **'Error picking image: {error}'**
  String errorPickingImage(String error);

  /// Pro Stock class category
  ///
  /// In en, this message translates to:
  /// **'Pro Stock'**
  String get proStock;

  /// Pro Mod class category
  ///
  /// In en, this message translates to:
  /// **'Pro Mod'**
  String get proMod;

  /// Top Alcohol class category
  ///
  /// In en, this message translates to:
  /// **'Top Alcohol'**
  String get topAlcohol;

  /// Competition Eliminator class category
  ///
  /// In en, this message translates to:
  /// **'Competition Eliminator'**
  String get competitionEliminator;

  /// Super Comp class category
  ///
  /// In en, this message translates to:
  /// **'Super Comp'**
  String get superComp;

  /// Error message when profile submission fails
  ///
  /// In en, this message translates to:
  /// **'Error submitting profile: {error}'**
  String errorSubmittingProfile(String error);

  /// Loading message when submitting profile
  ///
  /// In en, this message translates to:
  /// **'Submitting profile...'**
  String get submittingProfile;

  /// Hint text for street address field
  ///
  /// In en, this message translates to:
  /// **'Enter your street address'**
  String get streetHint;

  /// Hint text for zip/postal code field
  ///
  /// In en, this message translates to:
  /// **'Enter zip code first for better results'**
  String get zipHint;

  /// Title for PWC management screen
  ///
  /// In en, this message translates to:
  /// **'PWC Management'**
  String get pwcManagement;

  /// Button to add a new PWC
  ///
  /// In en, this message translates to:
  /// **'Add PWC'**
  String get addPWC;

  /// No description provided for @pwcName.
  ///
  /// In en, this message translates to:
  /// **'PWC Name'**
  String get pwcName;

  /// No description provided for @pwcNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for your PWC'**
  String get pwcNameHint;

  /// Title for editing a PWC
  ///
  /// In en, this message translates to:
  /// **'Edit PWC'**
  String get editPWC;

  /// Message when user has no PWCs
  ///
  /// In en, this message translates to:
  /// **'No PWCs have been registered yet'**
  String get noPWCs;

  /// Message encouraging user to add their first PWC
  ///
  /// In en, this message translates to:
  /// **'Add your first personal watercraft to get started'**
  String get addPWCToGetStarted;

  /// Label for primary PWC
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primary;

  /// Action to set a PWC as primary
  ///
  /// In en, this message translates to:
  /// **'Set as Primary'**
  String get setAsPrimary;

  /// Title for delete PWC confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete PWC'**
  String get deletePWC;

  /// Confirmation message for deleting a PWC
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this PWC? This action cannot be undone.'**
  String get deletePWCConfirmation;

  /// Delete button text
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Success message after deleting a PWC
  ///
  /// In en, this message translates to:
  /// **'PWC deleted successfully'**
  String get pwcDeleted;

  /// Error message when deleting PWC fails
  ///
  /// In en, this message translates to:
  /// **'Error deleting PWC'**
  String get errorDeletingPWC;

  /// Error message when saving PWC fails
  ///
  /// In en, this message translates to:
  /// **'Error saving PWC'**
  String get errorSavingPWC;

  /// Generic error label
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Retry button text
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Title for server unavailable screen
  ///
  /// In en, this message translates to:
  /// **'Server Unavailable'**
  String get serverUnavailableTitle;

  /// Message shown when server is unreachable
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the server. Please check your connection and try again.'**
  String get serverUnavailableMessage;

  /// Button to retry connecting to server
  ///
  /// In en, this message translates to:
  /// **'Retry Connection'**
  String get retryConnection;

  /// Button to continue without server (e.g. logout)
  ///
  /// In en, this message translates to:
  /// **'Continue Offline'**
  String get continueOffline;

  /// Placeholder for make dropdown
  ///
  /// In en, this message translates to:
  /// **'Select Make'**
  String get selectMake;

  /// Hint for make text field
  ///
  /// In en, this message translates to:
  /// **'Enter Make'**
  String get enterMake;

  /// Validation error for required make field
  ///
  /// In en, this message translates to:
  /// **'Make is required'**
  String get makeRequired;

  /// Hint for model text field
  ///
  /// In en, this message translates to:
  /// **'Enter Model'**
  String get enterModel;

  /// Validation error for required model field
  ///
  /// In en, this message translates to:
  /// **'Model is required'**
  String get modelRequired;

  /// Year label
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// Hint for year field
  ///
  /// In en, this message translates to:
  /// **'Enter Year'**
  String get enterYear;

  /// Validation error for invalid year
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid year'**
  String get invalidYear;

  /// Placeholder for engine class dropdown
  ///
  /// In en, this message translates to:
  /// **'Select Engine Class'**
  String get selectEngineClass;

  /// Engine size label
  ///
  /// In en, this message translates to:
  /// **'Engine Size'**
  String get engineSize;

  /// Hint for engine size field
  ///
  /// In en, this message translates to:
  /// **'Enter Engine Size (e.g., 1100cc)'**
  String get enterEngineSize;

  /// Color label
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// Hint for color field
  ///
  /// In en, this message translates to:
  /// **'Enter Color'**
  String get enterColor;

  /// Registration number label
  ///
  /// In en, this message translates to:
  /// **'Registration Number'**
  String get registrationNumber;

  /// Hint for registration number field
  ///
  /// In en, this message translates to:
  /// **'Enter Registration Number'**
  String get enterRegistrationNumber;

  /// Serial number label
  ///
  /// In en, this message translates to:
  /// **'Serial Number'**
  String get serialNumber;

  /// Hint for serial number field
  ///
  /// In en, this message translates to:
  /// **'Enter Serial Number'**
  String get enterSerialNumber;

  /// Notes label
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Hint for notes field
  ///
  /// In en, this message translates to:
  /// **'Additional notes or custom modifications'**
  String get additionalNotes;

  /// Checkbox label for setting PWC as primary
  ///
  /// In en, this message translates to:
  /// **'Set as Primary PWC'**
  String get setAsPrimaryPWC;

  /// Description for primary PWC checkbox
  ///
  /// In en, this message translates to:
  /// **'This will be your default PWC for race registrations'**
  String get primaryPWCDescription;

  /// Text showing additional items count
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String andMore(int count);

  /// Title for registered racers section
  ///
  /// In en, this message translates to:
  /// **'Registered Racers'**
  String get registeredRacers;

  /// Message when no racers have registered for an event
  ///
  /// In en, this message translates to:
  /// **'No racers registered yet.'**
  String get noRacersRegistered;

  /// Title for registration step 1
  ///
  /// In en, this message translates to:
  /// **'Select Class & PWC'**
  String get selectClassAndPWC;

  /// Description for class and PWC selection
  ///
  /// In en, this message translates to:
  /// **'Choose your racing class and the PWC you\'ll be racing with.'**
  String get selectClassAndPWCDescription;

  /// Label for PWC selection
  ///
  /// In en, this message translates to:
  /// **'Select Personal Watercraft'**
  String get selectPWC;

  /// Error message when PWC is not selected
  ///
  /// In en, this message translates to:
  /// **'Please select a PWC'**
  String get pwcRequired;

  /// Message when user has no PWCs
  ///
  /// In en, this message translates to:
  /// **'No PWCs Found'**
  String get noPWCsFound;

  /// Message prompting user to add PWC first
  ///
  /// In en, this message translates to:
  /// **'You need to add a PWC to your account before registering for an event.'**
  String get addPWCFirst;

  /// Label for class/division selection
  ///
  /// In en, this message translates to:
  /// **'Class / Division'**
  String get classDivision;

  /// Hint for class division dropdown
  ///
  /// In en, this message translates to:
  /// **'Select Class / Division'**
  String get selectClassDivision;

  /// Helper text for class division selection
  ///
  /// In en, this message translates to:
  /// **'Choose the racing class you\'ll compete in'**
  String get classDivisionHelper;

  /// Validation error for class division
  ///
  /// In en, this message translates to:
  /// **'Class/Division is required'**
  String get classDivisionRequired;

  /// Label for selected PWC summary
  ///
  /// In en, this message translates to:
  /// **'Selected PWC'**
  String get selectedPWC;

  /// Hint for transponder ID field
  ///
  /// In en, this message translates to:
  /// **'Enter your transponder ID (optional)'**
  String get transponderIdHint;

  /// Message when navigating to waiver
  ///
  /// In en, this message translates to:
  /// **'Proceeding to waiver...'**
  String get proceedingToWaiver;

  /// Title for payment step
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentStep;

  /// Description for payment step placeholder
  ///
  /// In en, this message translates to:
  /// **'Payment integration will be available soon.'**
  String get paymentStepDescription;

  /// Button text to proceed to waiver
  ///
  /// In en, this message translates to:
  /// **'Continue to Waiver'**
  String get continueToWaiver;

  /// Button text to complete payment
  ///
  /// In en, this message translates to:
  /// **'Complete Payment'**
  String get completePayment;

  /// Message when payment is not yet implemented
  ///
  /// In en, this message translates to:
  /// **'Payment integration coming soon'**
  String get paymentNotYetImplemented;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred'**
  String get unknownError;

  /// Network error message
  ///
  /// In en, this message translates to:
  /// **'Network connection error. Please check your internet connection.'**
  String get networkError;

  /// Timeout error message
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Please try again.'**
  String get timeoutError;

  /// Server error message
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get serverError;

  /// Unauthorized error message
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please log in again.'**
  String get unauthorizedError;

  /// Not found error message
  ///
  /// In en, this message translates to:
  /// **'Resource not found.'**
  String get notFoundError;

  /// Validation error message
  ///
  /// In en, this message translates to:
  /// **'Invalid data provided. Please check your input.'**
  String get validationError;

  /// Rate limit error message
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait a moment and try again.'**
  String get rateLimitError;

  /// OK button text
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Sign out button text
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Sign out confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirmation;

  /// Title for important information section
  ///
  /// In en, this message translates to:
  /// **'Important Information'**
  String get importantInformation;

  /// Message about reading waiver carefully
  ///
  /// In en, this message translates to:
  /// **'Read the full waiver carefully before signing'**
  String get readWaiverCarefully;

  /// Hint about language toggle
  ///
  /// In en, this message translates to:
  /// **'You can change the language using the toggle in the app bar'**
  String get languageToggleHint;

  /// Message when PDF download is not yet available
  ///
  /// In en, this message translates to:
  /// **'PDF download coming soon'**
  String get downloadPdfComingSoon;

  /// Message when registration details view is not yet available
  ///
  /// In en, this message translates to:
  /// **'Registration details coming soon'**
  String get viewRegistrationComingSoon;

  /// No description provided for @addClassEntry.
  ///
  /// In en, this message translates to:
  /// **'Add another class'**
  String get addClassEntry;

  /// No description provided for @removeClassEntry.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeClassEntry;

  /// No description provided for @purchaseIhraMembershipWithRegistration.
  ///
  /// In en, this message translates to:
  /// **'Purchase IHRA membership with registration'**
  String get purchaseIhraMembershipWithRegistration;

  /// No description provided for @validIhraMembershipDescription.
  ///
  /// In en, this message translates to:
  /// **'Valid IHRA membership requires a membership number and purchase within this calendar year. Add membership purchase to your registration if needed.'**
  String get validIhraMembershipDescription;

  /// No description provided for @spectatorDayPasses.
  ///
  /// In en, this message translates to:
  /// **'Additional day passes (spectator tickets)'**
  String get spectatorDayPasses;

  /// No description provided for @spectatorDayPassesDescription.
  ///
  /// In en, this message translates to:
  /// **'Purchase additional day passes for spectators before checkout.'**
  String get spectatorDayPassesDescription;

  /// No description provided for @dayPassesQuantity.
  ///
  /// In en, this message translates to:
  /// **'Number of day passes'**
  String get dayPassesQuantity;

  /// No description provided for @spectatorSingleDayPass.
  ///
  /// In en, this message translates to:
  /// **'Single day pass (\$30)'**
  String get spectatorSingleDayPass;

  /// No description provided for @spectatorWeekendPass.
  ///
  /// In en, this message translates to:
  /// **'Weekend pass (\$40)'**
  String get spectatorWeekendPass;

  /// No description provided for @classesAndPwc.
  ///
  /// In en, this message translates to:
  /// **'Classes & PWC'**
  String get classesAndPwc;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get orderSummary;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @payWithPayPal.
  ///
  /// In en, this message translates to:
  /// **'Pay with PayPal'**
  String get payWithPayPal;

  /// No description provided for @afterPayPalReturn.
  ///
  /// In en, this message translates to:
  /// **'After completing payment in the browser, return to this app and tap below.'**
  String get afterPayPalReturn;

  /// No description provided for @iveCompletedPayment.
  ///
  /// In en, this message translates to:
  /// **'I\'ve completed payment'**
  String get iveCompletedPayment;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
