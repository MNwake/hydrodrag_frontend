import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../widgets/language_toggle.dart';
import '../l10n/app_localizations.dart';
import '../models/event.dart';
import '../models/hydrodrags_config.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../services/hydrodrags_config_service.dart';
import '../services/image_cache_service.dart';
import 'spectator_purchase_screen.dart';

class InfoTabScreen extends StatefulWidget {
  /// When set, the spectator ticket button will switch to the Events tab instead of pushing purchase.
  final VoidCallback? onPurchaseSpectatorTickets;

  const InfoTabScreen({super.key, this.onPurchaseSpectatorTickets});

  @override
  State<InfoTabScreen> createState() => _InfoTabScreenState();
}

class _InfoTabScreenState extends State<InfoTabScreen> {
  final HydroDragsConfigService _configService = HydroDragsConfigService();
  HydroDragsConfig? _config;
  bool _loading = true;
  Object? _error;
  List<Event> _events = [];
  bool _eventsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadEvents() async {
    if (_eventsLoaded) return;
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final eventService = EventService(authService);
      final events = await eventService.getEvents();
      if (mounted) {
        setState(() {
          _events = events;
          _eventsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _eventsLoaded = true);
    }
  }

  Future<void> _loadConfig() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await _configService.getConfig();
      if (mounted) {
        setState(() {
          _config = config;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.hydrodragsInfo),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: _error != null
          ? _buildErrorState(context)
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: _loading
                        ? _buildLoadingContent(context)
                        : Column(
                            children: [
                              _buildHeroSection(context),
                              _buildAboutSection(context),
                              _buildSpectatorTicketsSection(context),
                              if (_config?.news.isNotEmpty == true)
                                _buildNewsHeroCarousel(context),
                              _buildSponsorsSection(context),
                              _buildMediaPartnersSection(context),
                              _buildContactSection(context),
                              if (_config?.socialLinks.isNotEmpty == true)
                                _buildSocialLinksSection(context),
                              const SizedBox(height: 24),
                            ],
                          ),
                  ),
                );
              },
            ),
    );
  }

  /// Shown while config is loading so the page shell and hero appear immediately.
  Widget _buildLoadingContent(BuildContext context) {
    return Column(
      children: [
        _buildHeroSection(context),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              l10n.serverUnavailableTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$_error',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadConfig,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final title = _config?.companyName.isNotEmpty == true
        ? _config!.companyName
        : l10n.eventTitle2026;
    final tagline = _config?.taglineForLocale(locale) ??
        _config?.tagline ??
        l10n.itsTimeToSendIt;

    return Container(
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
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            tagline,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final aboutText = _config?.aboutForLocale(locale) ?? _config?.about;

    return _buildSection(
      context,
      title: l10n.aboutHydrodrags,
      icon: Icons.info,
      children: [
        const SizedBox(height: 8),
        if (aboutText != null && aboutText.isNotEmpty)
          Text(aboutText, style: theme.textTheme.bodyMedium)
        else ...[
          Text(l10n.aboutParagraph1, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(l10n.aboutParagraph2, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }

  Widget _buildSpectatorTicketsSection(BuildContext context) {
    if (!_eventsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadEvents());
    }
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    Event? openEvent;
    for (final e in _events) {
      if (e.isOpen) {
        openEvent = e;
        break;
      }
    }
    openEvent ??= _events.isNotEmpty ? _events.first : null;

    return _buildSection(
      context,
      title: l10n.purchaseSpectatorTickets,
      icon: Icons.confirmation_number_outlined,
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.purchaseSpectatorTicketsDescription,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              if (openEvent != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SpectatorPurchaseScreen(event: openEvent!),
                  ),
                );
              } else if (widget.onPurchaseSpectatorTickets != null) {
                widget.onPurchaseSpectatorTickets!();
              } else {
                Navigator.of(context).pushNamed('/main');
              }
            },
            icon: const Icon(Icons.confirmation_number, size: 20),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l10n.purchaseSpectatorTickets),
            ),
          ),
        ),
      ],
    );
  }

  static const double _newsHeroCarouselHeight = 320;

  Widget _buildNewsHeroCarousel(BuildContext context) {
    final news = _config!.news.where((n) => n.isActive).toList();
    if (news.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.newspaper, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'News & Updates',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _newsHeroCarouselHeight,
            child: _NewsHeroCarousel(items: news),
          ),
        ],
      ),
    );
  }

  Widget _buildSponsorsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fromServer = _config?.sponsors.where((s) => s.isActive).toList() ?? [];
    return _buildSection(
      context,
      title: l10n.ourSponsors,
      icon: Icons.star,
      children: [
        const SizedBox(height: 8),
        Text(l10n.sponsorsIntro, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        _buildSponsorGrid(context, fromServer),
      ],
    );
  }

  Widget _buildMediaPartnersSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fromServer = _config?.mediaPartners.where((s) => s.isActive).toList() ?? [];
    return _buildSection(
      context,
      title: l10n.mediaPartners,
      icon: Icons.video_library,
      children: [
        const SizedBox(height: 8),
        Text(l10n.mediaPartnersIntro, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        _buildMediaGrid(context, fromServer),
      ],
    );
  }

  Widget _buildContactSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final phone = _config?.phone ?? l10n.contactPhoneNumber;
    final email = _config?.email ?? _config?.supportEmail ?? l10n.contactEmailAddress;
    final contactChildren = <Widget>[
      const SizedBox(height: 8),
      if (phone.isNotEmpty)
        _buildContactCard(
          context,
          icon: Icons.phone,
          title: l10n.contactPhone,
          value: phone,
          onTap: () => _handlePhoneTap(context, phone),
        ),
      if (email.isNotEmpty)
        _buildContactCard(
          context,
          icon: Icons.email,
          title: l10n.contactEmail,
          value: email,
          onTap: () => _handleEmailTap(context, email),
        ),
      if (_config?.websiteUrl != null && _config!.websiteUrl!.isNotEmpty)
        _buildContactCard(
          context,
          icon: Icons.language,
          title: 'Website',
          value: _config!.websiteUrl!,
          onTap: () => _launchSponsorUrl(context, _config!.websiteUrl!),
        ),
    ];
    return _buildSection(
      context,
      title: l10n.contactUs,
      icon: Icons.contact_mail,
      children: contactChildren,
    );
  }

  Widget _buildSocialLinksSection(BuildContext context) {
    final theme = Theme.of(context);
    final links = _config!.socialLinks;
    return _buildSection(
      context,
      title: 'Follow us',
      icon: Icons.share,
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: links
              .map((link) => ActionChip(
                    label: Text(link.platform),
                    onPressed: () => _launchSponsorUrl(context, link.url),
                    avatar: Icon(Icons.open_in_new, size: 18, color: theme.colorScheme.primary),
                  ))
              .toList(),
        ),
      ],
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
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSponsorGrid(BuildContext context, List<Sponsor> fromServer) {
    final theme = Theme.of(context);

    if (fromServer.isNotEmpty) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemCount: fromServer.length,
        itemBuilder: (context, index) {
          final sponsor = fromServer[index];
          final imageUrl = sponsor.logoUrl != null && sponsor.logoUrl!.isNotEmpty
              ? (sponsor.logoUrl!.startsWith('http')
                  ? sponsor.logoUrl
                  : ImageCacheService.getImageUrl(sponsor.logoUrl))
              : null;
          final url = sponsor.websiteUrl;
          return Card(
            elevation: 2,
            child: InkWell(
              onTap: url != null && url.isNotEmpty
                  ? () => _launchSponsorUrl(context, url)
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          cacheWidth: 200,
                          cacheHeight: 200,
                          gaplessPlayback: true,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: Icon(
                                  Icons.business_outlined,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 32,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.business,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 32,
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Icon(
                            Icons.business,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 32,
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      );
    }

    // Fallback: hardcoded sponsor assets when no server data
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

  Widget _buildMediaGrid(BuildContext context, List<Sponsor> fromServer) {
    final theme = Theme.of(context);

    if (fromServer.isNotEmpty) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: fromServer.length,
        itemBuilder: (context, index) {
          final partner = fromServer[index];
          final imageUrl = partner.logoUrl != null && partner.logoUrl!.isNotEmpty
              ? (partner.logoUrl!.startsWith('http')
                  ? partner.logoUrl
                  : ImageCacheService.getImageUrl(partner.logoUrl))
              : null;
          final url = partner.websiteUrl;
          return Card(
            elevation: 2,
            child: InkWell(
              onTap: url != null && url.isNotEmpty
                  ? () => _launchSponsorUrl(context, url)
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                cacheWidth: 240,
                                cacheHeight: 240,
                                gaplessPlayback: true,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: Center(
                                      child: Icon(
                                        Icons.video_library_outlined,
                                        color: theme.colorScheme.onSurfaceVariant,
                                        size: 48,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      Icons.video_library,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      size: 48,
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Icon(
                                  Icons.video_library,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 48,
                                ),
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: Text(
                        partner.name,
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

    // Fallback: hardcoded media partners when no server data
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

/// Extracts YouTube video ID from common URL formats.
String? _youtubeVideoId(String? url) {
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.host.contains('youtu.be')) {
    final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    return id;
  }
  if (uri.host.contains('youtube.com')) {
    return uri.queryParameters['v'];
  }
  return null;
}

/// Horizontal swipe carousel of news items with dot indicator
class _NewsHeroCarousel extends StatefulWidget {
  final List<NewsItem> items;

  const _NewsHeroCarousel({required this.items});

  @override
  State<_NewsHeroCarousel> createState() => _NewsHeroCarouselState();
}

class _NewsHeroCarouselState extends State<_NewsHeroCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (int index) {
              setState(() => _currentPage = index);
            },
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox.expand(
                  child: _NewsHeroSlide(item: widget.items[index]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.items.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 10 : 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Single news slide: card with title, description, and 16:9 media (YouTube or image)
class _NewsHeroSlide extends StatefulWidget {
  final NewsItem item;

  const _NewsHeroSlide({required this.item});

  @override
  State<_NewsHeroSlide> createState() => _NewsHeroSlideState();
}

class _NewsHeroSlideState extends State<_NewsHeroSlide> {
  YoutubePlayerController? _youtubeController;

  @override
  void initState() {
    super.initState();
    final videoId = _youtubeVideoId(widget.item.mediaUrl);
    if (videoId != null && videoId.isNotEmpty) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    try {
      _youtubeController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasYoutube = _youtubeController != null;
    final mediaUrl = widget.item.mediaUrl;
    final hasImage = !hasYoutube && mediaUrl != null && mediaUrl.isNotEmpty;
    final imageUrl = hasImage
        ? (mediaUrl.startsWith('http')
            ? mediaUrl
            : ImageCacheService.getImageUrl(mediaUrl))
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.article_outlined, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.item.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.item.description != null &&
                          widget.item.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.item.description!,
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    final targetRatio = 16 / 9;
                    final width = w <= h * targetRatio ? w : h * targetRatio;
                    final height = w <= h * targetRatio ? w / targetRatio : h;
                    return SizedBox(
                      width: width,
                      height: height,
                      child: _youtubeController != null
                          ? YoutubePlayer(
                              controller: _youtubeController!,
                              showVideoProgressIndicator: true,
                              progressIndicatorColor: theme.colorScheme.primary,
                              progressColors: ProgressBarColors(
                                playedColor: theme.colorScheme.primary,
                                handleColor: theme.colorScheme.primary,
                              ),
                            )
                          : imageUrl != null
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  cacheWidth: 640,
                                  cacheHeight: 360,
                                  gaplessPlayback: true,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return _mediaPlaceholder(theme);
                                  },
                                  errorBuilder: (context, error, stackTrace) =>
                                      _mediaPlaceholder(theme),
                                )
                              : _mediaPlaceholder(theme),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
