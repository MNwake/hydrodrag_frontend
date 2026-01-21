class Waiver {
  final String id;
  final String version;
  final String language; // 'en' or 'es'
  final String title;
  final String content;
  final DateTime createdAt;

  Waiver({
    required this.id,
    required this.version,
    required this.language,
    required this.title,
    required this.content,
    required this.createdAt,
  });
}

class WaiverSignature {
  final String waiverId;
  final String fullLegalName;
  final String signatureData; // Base64 encoded signature drawing
  final DateTime signedAt;
  final String? deviceInfo;
  final String? ipAddress;

  WaiverSignature({
    required this.waiverId,
    required this.fullLegalName,
    required this.signatureData,
    required this.signedAt,
    this.deviceInfo,
    this.ipAddress,
  });
}