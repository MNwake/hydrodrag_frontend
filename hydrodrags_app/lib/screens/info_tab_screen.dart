import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../widgets/language_toggle.dart';
import '../l10n/app_localizations.dart';

class InfoTabScreen extends StatefulWidget {
  const InfoTabScreen({super.key});

  @override
  State<InfoTabScreen> createState() => _InfoTabScreenState();
}

class _InfoTabScreenState extends State<InfoTabScreen> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.hydrodragsInfo),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Column(
                children: [
                  // Hero section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.eventTitle2026,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.itsTimeToSendIt,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // About Section
            _buildSection(
              context,
              title: l10n.aboutHydrodrags,
              icon: Icons.info,
              children: [
                const SizedBox(height: 8),
                Text(
                  l10n.aboutParagraph1,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.aboutParagraph2,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _buildWorldRecordCard(context),
                _buildInfoCard(
                  context,
                  icon: Icons.people,
                  title: l10n.ageRequirement,
                  description: l10n.ageRequirementDescription,
                ),
                _buildInfoCard(
                  context,
                  icon: Icons.badge,
                  title: l10n.isjbaMembershipRequired,
                  description: l10n.isjbaMembershipDescription,
                ),
              ],
            ),

            // Sponsors
            _buildSection(
              context,
              title: l10n.ourSponsors,
              icon: Icons.star,
              children: [
                const SizedBox(height: 8),
                Text(
                  l10n.sponsorsIntro,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _buildSponsorGrid(context),
              ],
            ),

            // Media Partners
            _buildSection(
              context,
              title: l10n.mediaPartners,
              icon: Icons.video_library,
              children: [
                const SizedBox(height: 8),
                Text(
                  l10n.mediaPartnersIntro,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _buildMediaGrid(context),
              ],
            ),

            // Contact
            _buildSection(
              context,
              title: l10n.contactUs,
              icon: Icons.contact_mail,
              children: [
                const SizedBox(height: 8),
                _buildContactCard(
                  context,
                  icon: Icons.phone,
                  title: l10n.contactPhone,
                  value: l10n.contactPhoneNumber,
                  onTap: () => _handlePhoneTap(context, l10n.contactPhoneNumber),
                ),
                _buildContactCard(
                  context,
                  icon: Icons.email,
                  title: l10n.contactEmail,
                  value: l10n.contactEmailAddress,
                  onTap: () => _handleEmailTap(context, l10n.contactEmailAddress),
                ),
              ],
            ),

            const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
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
    return Padding(
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
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildWorldRecordCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _WorldRecordCard(
      title: l10n.worldRecordSpeed,
      description: l10n.worldRecordDescription,
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaCard(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.video_library, color: theme.colorScheme.primary),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(description),
      ),
    );
  }

  Widget _buildSponsorGrid(BuildContext context) {
    final theme = Theme.of(context);
    
    // Sponsor image paths and URLs from https://quadlifeentertainment.com/sponsors/
    final sponsors = <Map<String, String?>>[
      {'image': 'assets/images/sponsors/fuel_tech.png', 'url': 'https://www.fueltech.net/'},
      {'image': 'assets/images/sponsors/florida_ski_riders.png', 'url': 'https://flskiriders.com/'},
      {'image': 'assets/images/sponsors/racer_h2o.jpg', 'url': 'http://www.romesburgmedia.com/racerh2o/'},
      {'image': 'assets/images/sponsors/broward.png', 'url': 'https://www.browardmotorsports.com/'},
      {'image': 'assets/images/sponsors/angelica_racing.jpg', 'url': 'https://flskiriders.com/catch-her-if-you-can-angelica-racing/'},
      {'image': 'assets/images/sponsors/fizzle.jpg', 'url': 'https://www.fizzlefactory.com/default.asp'},
      {'image': 'assets/images/sponsors/jl_performance.png', 'url': 'https://jlperformanceusa.com/'},
      {'image': 'assets/images/sponsors/hydroturf.png', 'url': 'https://www.hydroturf.com/'},
      {'image': 'assets/images/sponsors/riva_racing.png', 'url': 'https://www.rivaracing.com/'},
      {'image': 'assets/images/sponsors/ProV.png', 'url': 'https://racevalves.com/'},
      {'image': 'assets/images/sponsors/jet_tribe_racing.jpg', 'url': 'https://www.jettribe.com/'},
      {'image': 'assets/images/sponsors/ijsba.png', 'url': 'https://ijsba.com/'},
      {'image': 'assets/images/sponsors/blowsion.png', 'url': 'https://www.blowsion.com/'},
      {'image': 'assets/images/sponsors/mowhawk.png', 'url': 'https://mohawkpier.com/'},
      {'image': 'assets/images/sponsors/ls_powder_coating.jpg', 'url': 'https://www.lspowdercoating.com/'},
      {'image': 'assets/images/sponsors/millenium_custom.jpg', 'url': 'https://www.facebook.com/millenniumcustom'},
      {'image': 'assets/images/sponsors/south_bay_fuel.png', 'url': 'https://www.southbayfuelinjectors.com/'},
      {'image': 'assets/images/sponsors/wavedek.jpg', 'url': 'https://www.instagram.com/wavedek_miami/'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: sponsors.length,
      itemBuilder: (context, index) {
        final sponsor = sponsors[index];
        final imagePath = sponsor['image']!;
        final url = sponsor['url'];
        return Card(
          elevation: 2,
          child: InkWell(
            onTap: url != null ? () => _launchSponsorUrl(context, url) : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(
                        Icons.business,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 32,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchSponsorUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  Widget _buildMediaGrid(BuildContext context) {
    final theme = Theme.of(context);
    
    // Media partner image paths, titles, and URLs (from quadlifeentertainment.com)
    final mediaPartners = [
      {'image': 'assets/images/media/racer_h2o.jpg', 'title': 'Racer H2O', 'url': 'http://www.romesburgmedia.com/racerh2o/'},
      {'image': 'assets/images/media/florida_ski_riders.png', 'title': 'Florida Ski Riders', 'url': 'https://flskiriders.com/'},
      {'image': 'assets/images/media/mvp_productions.jpg', 'title': 'MVP Productions', 'url': null},
      {'image': 'assets/images/media/pro_rider.png', 'title': 'Pro Rider Magazine', 'url': 'https://www.proridermag.com/'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: mediaPartners.length,
      itemBuilder: (context, index) {
        final partner = mediaPartners[index];
        final url = partner['url'] as String?;
        return Card(
          elevation: 2,
          child: InkWell(
            onTap: url != null ? () => _launchSponsorUrl(context, url) : null,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        partner['image'] as String,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.video_library,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 48,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: Text(
                      partner['title'] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Future<void> _handlePhoneTap(BuildContext context, String phoneNumber) async {
    // Remove any non-digit characters except + for international numbers
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Call'),
                onTap: () async {
                  Navigator.pop(context);
                  final uri = Uri.parse('tel:$cleanedNumber');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Unable to make phone call')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.message),
                title: const Text('Text Message'),
                onTap: () async {
                  Navigator.pop(context);
                  final uri = Uri.parse('sms:$cleanedNumber');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Unable to send text message')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleEmailTap(BuildContext context, String emailAddress) async {
    final uri = Uri.parse('mailto:$emailAddress');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open email client')),
        );
      }
    }
  }
}

/// Widget for displaying world record information with embedded YouTube video
class _WorldRecordCard extends StatefulWidget {
  final String title;
  final String description;

  const _WorldRecordCard({
    required this.title,
    required this.description,
  });

  @override
  State<_WorldRecordCard> createState() => _WorldRecordCardState();
}

class _WorldRecordCardState extends State<_WorldRecordCard> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    // Extract video ID from URL: https://youtu.be/jlq0KClDbgo?si=HYt5AwROXzx9Qx83
    const videoId = 'jlq0KClDbgo';
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: true,
      ),
    );
  }

  @override
  void dispose() {
    try {
      _controller.dispose();
    } catch (_) {
      // WebView may already be disposed by YoutubePlayer on unmount (e.g. hot
      // restart, tab switch). Swallow to avoid "used after being disposed" crash.
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.speed, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // YouTube video embed (constrained to avoid overflow)
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: w,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: YoutubePlayer(
                        controller: _controller,
                        showVideoProgressIndicator: true,
                        progressIndicatorColor: theme.colorScheme.primary,
                        progressColors: ProgressBarColors(
                          playedColor: theme.colorScheme.primary,
                          handleColor: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
