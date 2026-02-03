import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/auth_service.dart';
import '../services/app_state_service.dart';
import '../services/racer_service.dart';
import '../services/error_handler_service.dart';
import '../services/image_cache_service.dart';
import '../widgets/language_toggle.dart';
import '../models/racer_profile.dart';
import '../utils/phone_formatter.dart';
import '../l10n/app_localizations.dart';
import 'login_screen.dart';
import 'pwc_management_screen.dart';
import 'bio_edit_screen.dart';
import 'sponsors_edit_screen.dart';

class AccountManagementTabScreen extends StatefulWidget {
  const AccountManagementTabScreen({super.key});

  @override
  State<AccountManagementTabScreen> createState() => _AccountManagementTabScreenState();
}

class _AccountManagementTabScreenState extends State<AccountManagementTabScreen> {
  RacerProfile? _profile;
  bool _isLoading = true;
  bool _profileImageLoadFailed = false;
  bool _bannerImageLoadFailed = false;
  AppStateService? _appState;
  final ImagePicker _imagePicker = ImagePicker();
  final ImageCacheService _imageCache = ImageCacheService();
  File? _cachedProfileImage;
  File? _cachedBannerImage;

  bool _editingName = false;
  bool _editingPhone = false;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final FocusNode _nameFocusNode;
  late final FocusNode _phoneFocusNode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState ??= Provider.of<AppStateService>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _nameFocusNode = FocusNode();
    _phoneFocusNode = FocusNode();
    _nameFocusNode.addListener(_onNameFocusChange);
    _phoneFocusNode.addListener(_onPhoneFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
      _appState?.addListener(_onProfileChanged);
    });
  }

  void _onNameFocusChange() {
    if (_nameFocusNode.hasFocus) return;
    _commitNameEdit();
  }

  void _onPhoneFocusChange() {
    if (_phoneFocusNode.hasFocus) return;
    _commitPhoneEdit();
  }

  void _commitNameEdit() {
    if (!_editingName || !mounted) return;
    final first = _profile?.firstName ?? '';
    final last = _profile?.lastName ?? '';
    final full = '${first} ${last}'.trim();
    final next = _nameController.text.trim();
    setState(() => _editingName = false);
    if (next != full) {
      final parts = next.isEmpty ? <String>[] : next.split(RegExp(r'\s+'));
      final f = parts.isEmpty ? '' : parts.first;
      final l = parts.length <= 1 ? '' : parts.sublist(1).join(' ');
      _saveProfileFieldName(f, l);
    }
  }

  void _commitPhoneEdit() {
    if (!_editingPhone || !mounted) return;
    final raw = _phoneController.text.trim();
    setState(() => _editingPhone = false);
    if (PhoneFormatter.validatePhoneNumber(raw) != null) return;
    final digits = PhoneFormatter.getDigitsOnly(PhoneFormatter.formatPhoneNumber(raw));
    final current = _profile?.phoneNumber ?? '';
    if (digits != current) {
      _saveProfileField('phone', digits);
    }
  }

  void _startEditName() {
    if (_profile == null) return;
    if (_editingPhone) {
      _phoneFocusNode.unfocus();
    }
    _nameController.text = _profile!.fullName;
    _nameController.selection = TextSelection.collapsed(offset: _nameController.text.length);
    setState(() => _editingName = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocusNode.requestFocus();
    });
  }

  void _startEditPhone() {
    if (_profile == null) return;
    if (_editingName) {
      _nameFocusNode.unfocus();
    }
    _phoneController.text = _profile!.phoneNumber != null
        ? PhoneFormatter.formatPhoneNumber(_profile!.phoneNumber!)
        : '';
    _phoneController.selection = TextSelection.collapsed(offset: _phoneController.text.length);
    setState(() => _editingPhone = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _phoneFocusNode.requestFocus();
    });
  }

  Future<void> _saveProfileFieldName(String first, String last) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final racerService = RacerService(authService);
      final currentProfile = _profile;
      if (currentProfile == null) throw Exception('Profile not loaded');
      final updatedProfile = RacerProfile(
        firstName: first.isEmpty ? null : first,
        lastName: last.isEmpty ? null : last,
        dateOfBirth: currentProfile.dateOfBirth,
        gender: currentProfile.gender,
        nationality: currentProfile.nationality,
        phoneNumber: currentProfile.phoneNumber,
        email: currentProfile.email,
        emergencyContactName: currentProfile.emergencyContactName,
        emergencyContactPhone: currentProfile.emergencyContactPhone,
        street: currentProfile.street,
        city: currentProfile.city,
        stateProvince: currentProfile.stateProvince,
        country: currentProfile.country,
        zipPostalCode: currentProfile.zipPostalCode,
        organization: currentProfile.organization,
        membershipNumber: currentProfile.membershipNumber,
        membershipPurchasedAt: currentProfile.membershipPurchasedAt,
        classCategory: currentProfile.classCategory,
        bio: currentProfile.bio,
        sponsors: currentProfile.sponsors,
      );
      final success = await racerService.updateRacerProfile(updatedProfile);
      if (mounted) {
        Navigator.pop(context);
        if (success) {
          await _loadProfile(forceRefresh: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.profileUpdated ?? 'Profile updated')),
            );
          }
        } else {
          ErrorHandlerService.showError(context, 'Failed to update profile');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ErrorHandlerService.logError(e, context: 'Save Name');
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  void _onProfileChanged() async {
    final appState = _appState;
    if (appState != null && mounted && appState.racerProfile != _profile) {
      final profile = appState.racerProfile;
      
      // Load images from cache
      File? cachedProfileImage;
      File? cachedBannerImage;
      
      if (profile != null) {
        if (profile.profileImagePath != null && profile.profileImagePath!.isNotEmpty) {
          cachedProfileImage = await _imageCache.getCachedImage(
            profile.profileImagePath,
            updatedAt: profile.profileImageUpdatedAt,
          );
        }
        if (profile.bannerImagePath != null && profile.bannerImagePath!.isNotEmpty) {
          cachedBannerImage = await _imageCache.getCachedImage(
            profile.bannerImagePath,
            updatedAt: profile.bannerImageUpdatedAt,
          );
        }
      }
      
      if (mounted) {
        setState(() {
          _profile = profile;
          _cachedProfileImage = cachedProfileImage;
          _cachedBannerImage = cachedBannerImage;
          _profileImageLoadFailed = false;
          _bannerImageLoadFailed = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameFocusNode.removeListener(_onNameFocusChange);
    _phoneFocusNode.removeListener(_onPhoneFocusChange);
    _nameController.dispose();
    _phoneController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _appState?.removeListener(_onProfileChanged);
    super.dispose();
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    final appState = Provider.of<AppStateService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    RacerProfile? profile;

    if (forceRefresh && authService.isAuthenticated) {
      final racerService = RacerService(authService);
      profile = await racerService.getCurrentRacerProfile();
      if (profile != null) {
        appState.setRacerProfile(profile);
      }
    } else {
      profile = appState.racerProfile;
      if (profile == null && authService.isAuthenticated) {
        final racerService = RacerService(authService);
        profile = await racerService.getCurrentRacerProfile();
        if (profile != null) {
          appState.setRacerProfile(profile);
        }
      }
    }
    
    // Load images from cache
    File? cachedProfileImage;
    File? cachedBannerImage;
    
    if (profile != null) {
      if (profile.profileImagePath != null && profile.profileImagePath!.isNotEmpty) {
        cachedProfileImage = await _imageCache.getCachedImage(
          profile.profileImagePath,
          updatedAt: profile.profileImageUpdatedAt,
        );
      }
      if (profile.bannerImagePath != null && profile.bannerImagePath!.isNotEmpty) {
        cachedBannerImage = await _imageCache.getCachedImage(
          profile.bannerImagePath,
          updatedAt: profile.bannerImageUpdatedAt,
        );
      }
    }
    
    if (mounted) {
      setState(() {
        _profile = profile;
        _cachedProfileImage = cachedProfileImage;
        _cachedBannerImage = cachedBannerImage;
        _isLoading = false;
        _profileImageLoadFailed = false;
        _bannerImageLoadFailed = false;
      });
    }
  }

  Future<void> _editBanner() async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(l10n.chooseFromGallery),
                onTap: () {
                  Navigator.pop(context);
                  _pickBanner(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(l10n.takeAPhoto),
                onTap: () {
                  Navigator.pop(context);
                  _pickBanner(ImageSource.camera);
                },
              ),
              if (_profile?.bannerImagePath != null && _profile!.bannerImagePath!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    l10n.removeBanner ?? 'Remove Banner',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeBanner();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickBanner(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        try {
          // Copy image to app's document directory
          final appDir = await getApplicationDocumentsDirectory();
          final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}${path.extension(pickedFile.path)}';
          final savedImage = await File(pickedFile.path).copy(path.join(appDir.path, fileName));
          
          // Upload to backend
          final authService = Provider.of<AuthService>(context, listen: false);
          final racerService = RacerService(authService);
          final uploaded = await racerService.uploadBannerImage(savedImage);
          
          if (mounted) {
            Navigator.pop(context); // Close loading dialog
            
            if (uploaded) {
              await _loadProfile(forceRefresh: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.bannerImageUpdated ?? 'Banner image updated')),
                );
              }
            } else {
              if (mounted) {
                ErrorHandlerService.showError(context, 'Failed to upload banner image');
              }
            }
          }
        } catch (e) {
          if (mounted) {
            Navigator.pop(context); // Close loading dialog
            ErrorHandlerService.logError(e, context: 'Upload Banner Image');
            ErrorHandlerService.showError(context, e);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandlerService.logError(e, context: 'Pick Banner Image');
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  Future<void> _removeBanner() async {
    // TODO: Implement backend endpoint to remove banner image
    // For now, just show a message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Banner image removal coming soon')),
      );
    }
  }

  Future<void> _editProfileImage() async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(l10n.chooseFromGallery),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(l10n.takeAPhoto),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_profile?.profileImagePath != null && _profile!.profileImagePath!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    l10n.removePhoto,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfileImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        try {
          // Copy image to app's document directory
          final appDir = await getApplicationDocumentsDirectory();
          final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}${path.extension(pickedFile.path)}';
          final savedImage = await File(pickedFile.path).copy(path.join(appDir.path, fileName));
          
          // Upload to backend
          final authService = Provider.of<AuthService>(context, listen: false);
          final racerService = RacerService(authService);
          final uploaded = await racerService.uploadProfileImage(savedImage);
          
          if (mounted) {
            Navigator.pop(context); // Close loading dialog
            
            if (uploaded) {
              await _loadProfile(forceRefresh: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.profileImageUpdated ?? 'Profile image updated')),
                );
              }
            } else {
              if (mounted) {
                ErrorHandlerService.showError(context, 'Failed to upload profile image');
              }
            }
          }
        } catch (e) {
          if (mounted) {
            Navigator.pop(context); // Close loading dialog
            ErrorHandlerService.logError(e, context: 'Upload Profile Image');
            ErrorHandlerService.showError(context, e);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandlerService.logError(e, context: 'Pick Profile Image');
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  Future<void> _removeProfileImage() async {
    // TODO: Implement backend endpoint to remove profile image
    // For now, just show a message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image removal coming soon')),
      );
    }
  }

  Future<void> _editBio() async {
    final profile = _profile;
    if (profile == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BioEditScreen(
          initialBio: profile.bio ?? '',
          onBioChanged: (bio) async {
            if (mounted) {
              await _saveProfileField('bio', bio);
            }
          },
        ),
      ),
    );
  }

  Future<void> _editSponsors() async {
    final profile = _profile;
    if (profile == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SponsorsEditScreen(
          initialSponsors: List<String>.from(profile.sponsors ?? []),
          onSponsorsChanged: (sponsors) async {
            if (mounted) {
              await _saveProfileFieldSponsors(sponsors);
            }
          },
        ),
      ),
    );
  }

  Future<void> _editMembershipPurchasedAt() async {
    final profile = _profile;
    if (profile == null) return;

    final l10n = AppLocalizations.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: profile.membershipPurchasedAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: l10n?.ihraMembershipPurchasedAtOptional ?? 'Membership purchased at',
    );
    if (picked == null || !mounted) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final racerService = RacerService(authService);
      final currentProfile = _profile;
      if (currentProfile == null) throw Exception('Profile not loaded');

      final updatedProfile = RacerProfile(
        firstName: currentProfile.firstName,
        lastName: currentProfile.lastName,
        dateOfBirth: currentProfile.dateOfBirth,
        gender: currentProfile.gender,
        nationality: currentProfile.nationality,
        phoneNumber: currentProfile.phoneNumber,
        email: currentProfile.email,
        emergencyContactName: currentProfile.emergencyContactName,
        emergencyContactPhone: currentProfile.emergencyContactPhone,
        street: currentProfile.street,
        city: currentProfile.city,
        stateProvince: currentProfile.stateProvince,
        country: currentProfile.country,
        zipPostalCode: currentProfile.zipPostalCode,
        organization: currentProfile.organization,
        membershipNumber: currentProfile.membershipNumber,
        membershipPurchasedAt: picked,
        classCategory: currentProfile.classCategory,
        bio: currentProfile.bio,
        sponsors: currentProfile.sponsors,
      );

      final success = await racerService.updateRacerProfile(updatedProfile);
      if (mounted) {
        Navigator.pop(context);
        if (success) {
          await _loadProfile(forceRefresh: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n?.profileUpdated ?? 'Profile updated')),
            );
          }
        } else {
          ErrorHandlerService.showError(context, 'Failed to update profile');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ErrorHandlerService.logError(e, context: 'Save Membership Purchased At');
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  Future<void> _saveProfileField(String field, String value) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final racerService = RacerService(authService);
      
      // Get current profile
      final currentProfile = _profile;
      if (currentProfile == null) {
        throw Exception('Profile not loaded');
      }

      // Create updated profile
      final updatedProfile = RacerProfile(
        firstName: field == 'first_name' ? value : currentProfile.firstName,
        lastName: field == 'last_name' ? value : currentProfile.lastName,
        dateOfBirth: currentProfile.dateOfBirth,
        gender: currentProfile.gender,
        nationality: currentProfile.nationality,
        phoneNumber: field == 'phone' ? value : currentProfile.phoneNumber,
        email: currentProfile.email,
        emergencyContactName: currentProfile.emergencyContactName,
        emergencyContactPhone: currentProfile.emergencyContactPhone,
        street: currentProfile.street,
        city: currentProfile.city,
        stateProvince: currentProfile.stateProvince,
        country: currentProfile.country,
        zipPostalCode: currentProfile.zipPostalCode,
        organization: currentProfile.organization,
        membershipNumber: currentProfile.membershipNumber,
        membershipPurchasedAt: currentProfile.membershipPurchasedAt,
        classCategory: currentProfile.classCategory,
        bio: field == 'bio' ? (value.isEmpty ? null : value) : currentProfile.bio,
        sponsors: currentProfile.sponsors,
      );

      final success = await racerService.updateRacerProfile(updatedProfile);
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        if (success) {
          await _loadProfile(forceRefresh: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.profileUpdated ?? 'Profile updated')),
            );
          }
        } else {
          ErrorHandlerService.showError(context, 'Failed to update profile');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ErrorHandlerService.logError(e, context: 'Save Profile Field');
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  Future<void> _saveProfileFieldSponsors(List<String> sponsors) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final racerService = RacerService(authService);

      final currentProfile = _profile;
      if (currentProfile == null) {
        throw Exception('Profile not loaded');
      }

      final updatedProfile = RacerProfile(
        firstName: currentProfile.firstName,
        lastName: currentProfile.lastName,
        dateOfBirth: currentProfile.dateOfBirth,
        gender: currentProfile.gender,
        nationality: currentProfile.nationality,
        phoneNumber: currentProfile.phoneNumber,
        email: currentProfile.email,
        emergencyContactName: currentProfile.emergencyContactName,
        emergencyContactPhone: currentProfile.emergencyContactPhone,
        street: currentProfile.street,
        city: currentProfile.city,
        stateProvince: currentProfile.stateProvince,
        country: currentProfile.country,
        zipPostalCode: currentProfile.zipPostalCode,
        organization: currentProfile.organization,
        membershipNumber: currentProfile.membershipNumber,
        membershipPurchasedAt: currentProfile.membershipPurchasedAt,
        classCategory: currentProfile.classCategory,
        bio: currentProfile.bio,
        sponsors: sponsors,
      );

      final success = await racerService.updateRacerProfile(updatedProfile);

      if (mounted) {
        Navigator.pop(context);
        if (success) {
          await _loadProfile(forceRefresh: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.profileUpdated ?? 'Profile updated')),
            );
          }
        } else {
          ErrorHandlerService.showError(context, 'Failed to update profile');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ErrorHandlerService.logError(e, context: 'Save Profile Field (Sponsors)');
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: authService.isAuthenticated
          ? _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildAuthenticatedView(context)
          : _buildUnauthenticatedView(context),
    );
  }

  Widget _buildUnauthenticatedView(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            Text(
              'Sign In Required',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please sign in to access your account and manage your racer profile.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.login),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Sign In'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticatedView(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context);
    final profile = _profile;

    // Use cached images
    final profileImage = !_profileImageLoadFailed ? _cachedProfileImage : null;
    final bannerImage = !_bannerImageLoadFailed ? _cachedBannerImage : null;

    // Get display name
    final displayName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : authService.email ?? 'User';

    // Get initials for avatar fallback
    final initials = _getInitials(displayName);
    
    // Format phone number for display
    String? displayPhone;
    if (profile?.phoneNumber != null && profile!.phoneNumber!.isNotEmpty) {
      displayPhone = PhoneFormatter.formatPhoneNumber(profile.phoneNumber!);
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Account header: banner + bottom bar with overlapping profile image
          _buildAccountHeader(
            context,
            theme: theme,
            bannerImage: bannerImage,
            profileImage: profileImage,
            initials: initials,
            displayName: displayName,
            authService: authService,
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Basic Information (Quick Edit)
                _buildSection(
                  context,
                  title: 'Basic Information',
                  children: [
                    _buildInlineEditableName(context, displayName),
                    if (authService.email != null)
                      _buildBasicInfoItem(
                        context,
                        icon: Icons.email,
                        label: 'Email',
                        value: authService.email!,
                        onTap: null, // Email can't be edited
                      ),
                    _buildInlineEditablePhone(context, displayPhone ?? ''),
                    _buildBasicInfoItem(
                      context,
                      icon: Icons.badge,
                      label: 'IHRA Membership #',
                      value: profile?.membershipNumber ?? '—',
                      onTap: null,
                    ),
                    _buildBasicInfoItem(
                      context,
                      icon: Icons.calendar_today,
                      label: AppLocalizations.of(context)?.ihraMembershipPurchasedAtOptional ?? 'IHRA Membership Purchased At (Optional)',
                      value: profile?.membershipPurchasedAt != null
                          ? '${profile!.membershipPurchasedAt!.month}/${profile.membershipPurchasedAt!.day}/${profile.membershipPurchasedAt!.year}'
                          : '—',
                      onTap: _editMembershipPurchasedAt,
                    ),
                  ],
                ),

                // Bio & Sponsors
                _buildSection(
                  context,
                  title: 'Bio & Sponsors',
                  children: [
                    _buildEditableTextItem(
                      context,
                      icon: Icons.description,
                      label: 'Bio',
                      value: profile?.bio ?? '',
                      placeholder: 'Tell us about yourself...',
                      onTap: _editBio,
                    ),
                    _buildEditableTextItem(
                      context,
                      icon: Icons.stars,
                      label: 'Sponsors',
                      value: profile?.sponsors?.join(', ') ?? '',
                      placeholder: 'Tap to add sponsors',
                      onTap: _editSponsors,
                    ),
                  ],
                ),

                // Profile Management
                _buildSection(
                  context,
                  title: 'Profile Management',
                  children: [
                    _buildMenuItem(
                      context,
                      icon: Icons.speed,
                      title: 'PWC Information',
                      subtitle: 'Manage your personal watercraft details',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PWCManagementScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // Sign Out
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final l10n = AppLocalizations.of(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(l10n?.signOut ?? 'Sign Out'),
                          content: Text(l10n?.signOutConfirmation ?? 'Are you sure you want to sign out?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(l10n?.cancel ?? 'Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                              ),
                              child: Text(l10n?.signOut ?? 'Sign Out'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && context.mounted) {
                        await authService.logout();
                        if (context.mounted) {
                          Navigator.of(context).pushReplacementNamed('/');
                        }
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(AppLocalizations.of(context)?.signOut ?? 'Sign Out'),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const double _headerBannerHeight = 160.0;
  static const double _headerBarHeight = 88.0;
  static const double _headerAvatarRadius = 44.0;

  Widget _buildAccountHeader(
    BuildContext context, {
    required ThemeData theme,
    required File? bannerImage,
    required File? profileImage,
    required String initials,
    required String displayName,
    required AuthService authService,
  }) {
    return SizedBox(
      height: _headerBannerHeight + _headerBarHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Banner (fills entire header; sits behind grey bar; bottom = bar bottom)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: bannerImage != null
                    ? DecorationImage(
                        image: FileImage(bannerImage),
                        fit: BoxFit.cover,
                        onError: (_, __) {
                          if (mounted) setState(() => _bannerImageLoadFailed = true);
                        },
                      )
                    : null,
                gradient: bannerImage == null
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primaryContainer,
                        ],
                      )
                    : null,
              ),
            ),
          ),
          if (bannerImage != null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.5),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          // 2. Grey bar (overlaid on bottom of banner; same bottom as banner)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _headerBarHeight,
            child: Container(
              color: theme.colorScheme.surface.withOpacity(0.75),
              padding: EdgeInsets.only(
                left: 16 + _headerAvatarRadius * 2 + 16,
                right: 16,
                top: 12,
                bottom: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Verified',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 3. Profile image (bottom-left, bottom aligned with bar)
          Positioned(
            left: 16,
            bottom: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: _headerAvatarRadius,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: profileImage != null ? FileImage(profileImage!) : null,
                  onBackgroundImageError: profileImage != null
                      ? (_, __) {
                          if (mounted) setState(() => _profileImageLoadFailed = true);
                        }
                      : null,
                  child: profileImage == null
                      ? Text(
                          initials,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _editProfileImage,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.surface, width: 2),
                      ),
                      child: Icon(Icons.edit, size: 14, color: theme.colorScheme.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 4. Banner edit (top right)
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: Icon(
                Icons.edit,
                color: bannerImage != null ? Colors.white : theme.colorScheme.onPrimary,
              ),
              onPressed: _editBanner,
              tooltip: AppLocalizations.of(context)?.editBanner ?? 'Edit Banner',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Card(
          child: Column(
            children: children,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }

  Widget _buildInlineEditableName(BuildContext context, String displayName) {
    final theme = Theme.of(context);
    if (_editingName) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.person, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Name',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: UnderlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _nameFocusNode.unfocus(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return ListTile(
      leading: Icon(Icons.person, color: theme.colorScheme.primary),
      title: Text(
        'Name',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        displayName.isEmpty ? 'Tap to add name' : displayName,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.edit, size: 20, color: theme.colorScheme.primary),
      onTap: _startEditName,
    );
  }

  Widget _buildInlineEditablePhone(BuildContext context, String displayPhone) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (_editingPhone) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.phone, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Phone',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _phoneController,
                    focusNode: _phoneFocusNode,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [PhoneNumberInputFormatter()],
                    decoration: const InputDecoration(
                      isDense: true,
                      border: UnderlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      hintText: '(XXX) XXX-XXXX',
                    ),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _phoneFocusNode.unfocus(),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () => _phoneFocusNode.unfocus(),
              tooltip: l10n?.save ?? 'Done',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      );
    }
    return ListTile(
      leading: Icon(Icons.phone, color: theme.colorScheme.primary),
      title: Text(
        'Phone',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        displayPhone.isEmpty ? 'Tap to add' : displayPhone,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.edit, size: 20, color: theme.colorScheme.primary),
      onTap: _startEditPhone,
    );
  }

  Widget _buildBasicInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: onTap != null
          ? Icon(Icons.edit, size: 20, color: theme.colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildEditableTextItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        value.isEmpty ? placeholder : value,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontStyle: value.isEmpty ? FontStyle.italic : FontStyle.normal,
          color: value.isEmpty 
              ? theme.colorScheme.onSurfaceVariant 
              : theme.colorScheme.onSurface,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(Icons.edit, size: 20, color: theme.colorScheme.primary),
      onTap: onTap,
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}
