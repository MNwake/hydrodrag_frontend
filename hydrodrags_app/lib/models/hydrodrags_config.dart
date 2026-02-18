/// Sponsor or media partner from HydroDrags config
class Sponsor {
  final String name;
  final String? logoUrl;
  final String? websiteUrl;
  final bool isActive;

  Sponsor({
    required this.name,
    this.logoUrl,
    this.websiteUrl,
    this.isActive = true,
  });

  factory Sponsor.fromJson(Map<String, dynamic> json) {
    return Sponsor(
      name: json['name'] as String? ?? '',
      logoUrl: json['logo_url'] as String?,
      websiteUrl: json['website_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// Social link (platform + url)
class SocialLink {
  final String platform;
  final String url;

  SocialLink({required this.platform, required this.url});

  factory SocialLink.fromJson(Map<String, dynamic> json) {
    return SocialLink(
      platform: json['platform'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}

/// Spanish-language content overrides
class SpanishContent {
  final String? about;
  final String? tagline;

  SpanishContent({this.about, this.tagline});

  factory SpanishContent.fromJson(Map<String, dynamic> json) {
    return SpanishContent(
      about: json['about'] as String?,
      tagline: json['tagline'] as String?,
    );
  }
}

/// Waiver from config (GET /hydrodrags/config)
class WaiverConfig {
  final String title;
  final String? version;
  final String? effectiveDate;
  final String content;
  final bool isActive;

  WaiverConfig({
    required this.title,
    this.version,
    this.effectiveDate,
    required this.content,
    this.isActive = true,
  });

  factory WaiverConfig.fromJson(Map<String, dynamic> json) {
    return WaiverConfig(
      title: json['title'] as String? ?? 'Release of Liability',
      version: json['version'] as String?,
      effectiveDate: json['effective_date'] as String?,
      content: json['content'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// News item for the info tab
class NewsItem {
  final String title;
  final String? description;
  final String? mediaUrl;
  final bool isActive;

  NewsItem({
    required this.title,
    this.description,
    this.mediaUrl,
    this.isActive = true,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      mediaUrl: json['media_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// Root config for the HydroDrags info tab (from GET /hydrodrags/config)
class HydroDragsConfig {
  final String companyName;
  /// Main headline for the info page hero (e.g. "2025 Fueltech US Nationals World Championships").
  final String? headline;
  /// URL or path for the logo image (e.g. "/assets/logo.png"). Resolve with API base URL.
  final String? logoUrl;
  /// URL or path for the banner image (e.g. "/assets/banner.png"). Resolve with API base URL.
  final String? bannerUrl;
  final String? about;
  final String? tagline;
  final SpanishContent? es;
  final List<NewsItem> news;
  final String? email;
  final String? phone;
  final String? supportEmail;
  final String? websiteUrl;
  final double ihraMembershipPrice;
  final double spectatorSingleDayPrice;
  final double spectatorWeekendPrice;
  final List<Sponsor> sponsors;
  final List<Sponsor> mediaPartners;
  final List<SocialLink> socialLinks;
  final WaiverConfig? waiver;
  final bool isActive;

  HydroDragsConfig({
    required this.companyName,
    this.headline,
    this.logoUrl,
    this.bannerUrl,
    this.about,
    this.tagline,
    this.es,
    this.news = const [],
    this.email,
    this.phone,
    this.supportEmail,
    this.websiteUrl,
    required this.ihraMembershipPrice,
    required this.spectatorSingleDayPrice,
    required this.spectatorWeekendPrice,
    this.sponsors = const [],
    this.mediaPartners = const [],
    this.socialLinks = const [],
    this.waiver,
    this.isActive = true,
  });

  factory HydroDragsConfig.fromJson(Map<String, dynamic> json) {
    return HydroDragsConfig(
      companyName: json['company_name'] as String? ?? '',
      headline: json['headline'] as String?,
      logoUrl: json['logo_url'] as String?,
      bannerUrl: json['banner_url'] as String?,
      about: json['about'] as String?,
      tagline: json['tagline'] as String?,
      es: json['es'] != null
          ? SpanishContent.fromJson(json['es'] as Map<String, dynamic>)
          : null,
      news: (json['news'] as List<dynamic>?)
              ?.map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      supportEmail: json['support_email'] as String?,
      websiteUrl: json['website_url'] as String?,
      ihraMembershipPrice:
          (json['ihra_membership_price'] as num?)?.toDouble() ?? 0,
      spectatorSingleDayPrice:
          (json['spectator_single_day_price'] as num?)?.toDouble() ?? 0,
      spectatorWeekendPrice:
          (json['spectator_weekend_price'] as num?)?.toDouble() ?? 0,
      sponsors: (json['sponsors'] as List<dynamic>?)
              ?.map((e) => Sponsor.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      mediaPartners: (json['media_partners'] as List<dynamic>?)
              ?.map((e) => Sponsor.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      socialLinks: (json['social_links'] as List<dynamic>?)
              ?.map((e) => SocialLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      waiver: json['waiver'] != null
          ? WaiverConfig.fromJson(json['waiver'] as Map<String, dynamic>)
          : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// About text for current locale (es if Spanish, else default about)
  String? aboutForLocale(String localeLanguageCode) {
    if (localeLanguageCode == 'es' && es?.about != null && es!.about!.isNotEmpty) {
      return es!.about;
    }
    return about;
  }

  /// Tagline for current locale (es if Spanish, else default tagline)
  String? taglineForLocale(String localeLanguageCode) {
    if (localeLanguageCode == 'es' && es?.tagline != null && es!.tagline!.isNotEmpty) {
      return es!.tagline;
    }
    return tagline;
  }
}
