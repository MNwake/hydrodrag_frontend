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

  /// No description provided for @racer.
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

  /// No description provided for @transponderId.
  ///
  /// In en, this message translates to:
  /// **'Transponder / ID Number'**
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
