import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pwc.dart';
import '../models/racer_profile.dart';
import '../services/auth_service.dart';
import '../services/image_cache_service.dart';
import '../services/racer_service.dart';
import '../widgets/language_toggle.dart';

class RacerProfileDetailScreen extends StatefulWidget {
  final RacerProfile racer;

  const RacerProfileDetailScreen({super.key, required this.racer});

  @override
  State<RacerProfileDetailScreen> createState() => _RacerProfileDetailScreenState();
}

class _RacerProfileDetailScreenState extends State<RacerProfileDetailScreen> {
  final ImageCacheService _imageCache = ImageCacheService();
  File? _cachedBannerImage;
  File? _cachedProfileImage;
  bool _imagesLoaded = false;
  List<PWC> _racerPWCs = [];
  bool _pwcsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadImages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadRacerPWCs();
    });
  }

  Future<void> _loadRacerPWCs() async {
    final id = widget.racer.id;
    if (id == null || id.isEmpty) {
      if (mounted) setState(() => _pwcsLoaded = true);
      return;
    }
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final racerService = RacerService(authService);
      final pwcs = await racerService.getRacerPWCs(id);
      if (mounted) {
        setState(() {
          _racerPWCs = pwcs;
          _pwcsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _pwcsLoaded = true);
    }
  }

  Future<void> _loadImages() async {
    File? bannerImage;
    File? profileImage;

    if (widget.racer.bannerImagePath != null && widget.racer.bannerImagePath!.isNotEmpty) {
      bannerImage = await _imageCache.getCachedImage(
        widget.racer.bannerImagePath,
        updatedAt: widget.racer.bannerImageUpdatedAt,
      );
    }
    if (widget.racer.profileImagePath != null && widget.racer.profileImagePath!.isNotEmpty) {
      profileImage = await _imageCache.getCachedImage(
        widget.racer.profileImagePath,
        updatedAt: widget.racer.profileImageUpdatedAt,
      );
    }

    if (mounted) {
      setState(() {
        _cachedBannerImage = bannerImage;
        _cachedProfileImage = profileImage;
        _imagesLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Racer Profile'),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header: banner + bottom bar with overlapping profile image
            _buildProfileHeader(context, theme),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Personal Information
                  if (widget.racer.firstName != null || widget.racer.lastName != null || widget.racer.dateOfBirth != null || widget.racer.gender != null || widget.racer.nationality != null)
                    _buildSection(
                      context,
                      title: 'Personal Information',
                      icon: Icons.person,
                      children: [
                        if (widget.racer.firstName != null)
                          _buildInfoRow(context, 'First Name', widget.racer.firstName!),
                        if (widget.racer.lastName != null)
                          _buildInfoRow(context, 'Last Name', widget.racer.lastName!),
                        if (widget.racer.dateOfBirth != null)
                          _buildInfoRow(context, 'Age', _ageFromDate(widget.racer.dateOfBirth!)),
                        if (widget.racer.gender != null)
                          _buildInfoRow(context, 'Gender', widget.racer.gender!),
                        if (widget.racer.nationality != null)
                          _buildInfoRow(context, 'Nationality', widget.racer.nationality!),
                      ],
                    ),

                  // Bio
                  _buildSection(
                    context,
                    title: 'Bio',
                    icon: Icons.description,
                    children: [
                      if (widget.racer.bio != null && widget.racer.bio!.isNotEmpty)
                        Text(
                          widget.racer.bio!,
                          style: theme.textTheme.bodyLarge,
                        )
                      else
                        Text(
                          'No bio yet.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),

                  // Sponsors
                  _buildSection(
                    context,
                    title: 'Sponsors',
                    icon: Icons.stars,
                    children: [
                      if (widget.racer.sponsors != null && widget.racer.sponsors!.isNotEmpty)
                        ...widget.racer.sponsors!.map((sponsor) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    sponsor.trim(),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                      else
                        Text(
                          'No sponsors yet.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),

                  // PWC Information
                  _buildSection(
                    context,
                    title: 'PWC Information',
                    icon: Icons.speed,
                    children: [
                      if (!_pwcsLoaded)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )),
                        )
                      else if (_racerPWCs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No PWCs listed.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        ..._racerPWCs.map((pwc) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (pwc.isPrimary)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Chip(
                                          label: Text(
                                            'Primary',
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: theme.colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        pwc.displayName,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (pwc.engineClass != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Engine: ${pwc.engineClass}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                if (pwc.modifications.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Mods: ${pwc.modifications.join(", ")}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),

                  // Results
                  _buildSection(
                    context,
                    title: 'Race Results',
                    icon: Icons.bar_chart,
                    children: [
                      Text(
                        'No results available yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const double _headerBannerHeight = 160.0;
  static const double _headerBarHeight = 88.0;
  static const double _headerAvatarRadius = 44.0;

  Widget _buildProfileHeader(BuildContext context, ThemeData theme) {
    final hasBanner = _cachedBannerImage != null;
    final displayName = widget.racer.fullName.isNotEmpty ? widget.racer.fullName : 'Unknown Racer';
    final initials = widget.racer.fullName.isNotEmpty ? widget.racer.fullName[0].toUpperCase() : '?';

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
                image: hasBanner
                    ? DecorationImage(
                        image: FileImage(_cachedBannerImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
                gradient: !hasBanner
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
          if (hasBanner)
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
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (widget.racer.classCategory != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.racer.classCategory!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 3. Profile image (bottom-left, bottom aligned with bar)
          Positioned(
            left: 16,
            bottom: 0,
            child: CircleAvatar(
              radius: _headerAvatarRadius,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage: _cachedProfileImage != null ? FileImage(_cachedProfileImage!) : null,
              child: _cachedProfileImage == null
                  ? Text(
                      initials,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {bool isPlaceholder = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
                color: isPlaceholder
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Returns age in years from [dateOfBirth] to today.
  String _ageFromDate(DateTime dateOfBirth) {
    final today = DateTime.now();
    int age = today.year - dateOfBirth.year;
    if (today.month < dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
      age--;
    }
    return '$age';
  }

}
