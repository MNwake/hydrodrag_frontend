/// Service for managing standardized location data (countries and states/provinces)
class LocationService {
  /// Standardized country list with ISO codes
  static const List<Country> countries = [
    Country(code: 'US', name: 'United States'),
    Country(code: 'CA', name: 'Canada'),
    Country(code: 'MX', name: 'Mexico'),
    Country(code: 'GB', name: 'United Kingdom'),
    Country(code: 'AU', name: 'Australia'),
    Country(code: 'NZ', name: 'New Zealand'),
    Country(code: 'OTHER', name: 'Other'), // Special code for custom country entry
    // Add more countries as needed
  ];

  /// US States with standardized abbreviations
  static const List<StateProvince> usStates = [
    StateProvince(code: 'AL', name: 'Alabama'),
    StateProvince(code: 'AK', name: 'Alaska'),
    StateProvince(code: 'AZ', name: 'Arizona'),
    StateProvince(code: 'AR', name: 'Arkansas'),
    StateProvince(code: 'CA', name: 'California'),
    StateProvince(code: 'CO', name: 'Colorado'),
    StateProvince(code: 'CT', name: 'Connecticut'),
    StateProvince(code: 'DE', name: 'Delaware'),
    StateProvince(code: 'FL', name: 'Florida'),
    StateProvince(code: 'GA', name: 'Georgia'),
    StateProvince(code: 'HI', name: 'Hawaii'),
    StateProvince(code: 'ID', name: 'Idaho'),
    StateProvince(code: 'IL', name: 'Illinois'),
    StateProvince(code: 'IN', name: 'Indiana'),
    StateProvince(code: 'IA', name: 'Iowa'),
    StateProvince(code: 'KS', name: 'Kansas'),
    StateProvince(code: 'KY', name: 'Kentucky'),
    StateProvince(code: 'LA', name: 'Louisiana'),
    StateProvince(code: 'ME', name: 'Maine'),
    StateProvince(code: 'MD', name: 'Maryland'),
    StateProvince(code: 'MA', name: 'Massachusetts'),
    StateProvince(code: 'MI', name: 'Michigan'),
    StateProvince(code: 'MN', name: 'Minnesota'),
    StateProvince(code: 'MS', name: 'Mississippi'),
    StateProvince(code: 'MO', name: 'Missouri'),
    StateProvince(code: 'MT', name: 'Montana'),
    StateProvince(code: 'NE', name: 'Nebraska'),
    StateProvince(code: 'NV', name: 'Nevada'),
    StateProvince(code: 'NH', name: 'New Hampshire'),
    StateProvince(code: 'NJ', name: 'New Jersey'),
    StateProvince(code: 'NM', name: 'New Mexico'),
    StateProvince(code: 'NY', name: 'New York'),
    StateProvince(code: 'NC', name: 'North Carolina'),
    StateProvince(code: 'ND', name: 'North Dakota'),
    StateProvince(code: 'OH', name: 'Ohio'),
    StateProvince(code: 'OK', name: 'Oklahoma'),
    StateProvince(code: 'OR', name: 'Oregon'),
    StateProvince(code: 'PA', name: 'Pennsylvania'),
    StateProvince(code: 'RI', name: 'Rhode Island'),
    StateProvince(code: 'SC', name: 'South Carolina'),
    StateProvince(code: 'SD', name: 'South Dakota'),
    StateProvince(code: 'TN', name: 'Tennessee'),
    StateProvince(code: 'TX', name: 'Texas'),
    StateProvince(code: 'UT', name: 'Utah'),
    StateProvince(code: 'VT', name: 'Vermont'),
    StateProvince(code: 'VA', name: 'Virginia'),
    StateProvince(code: 'WA', name: 'Washington'),
    StateProvince(code: 'WV', name: 'West Virginia'),
    StateProvince(code: 'WI', name: 'Wisconsin'),
    StateProvince(code: 'WY', name: 'Wyoming'),
    StateProvince(code: 'DC', name: 'District of Columbia'),
  ];

  /// Canadian Provinces and Territories
  static const List<StateProvince> canadianProvinces = [
    StateProvince(code: 'AB', name: 'Alberta'),
    StateProvince(code: 'BC', name: 'British Columbia'),
    StateProvince(code: 'MB', name: 'Manitoba'),
    StateProvince(code: 'NB', name: 'New Brunswick'),
    StateProvince(code: 'NL', name: 'Newfoundland and Labrador'),
    StateProvince(code: 'NS', name: 'Nova Scotia'),
    StateProvince(code: 'NT', name: 'Northwest Territories'),
    StateProvince(code: 'NU', name: 'Nunavut'),
    StateProvince(code: 'ON', name: 'Ontario'),
    StateProvince(code: 'PE', name: 'Prince Edward Island'),
    StateProvince(code: 'QC', name: 'Quebec'),
    StateProvince(code: 'SK', name: 'Saskatchewan'),
    StateProvince(code: 'YT', name: 'Yukon'),
  ];

  /// Mexican States
  static const List<StateProvince> mexicanStates = [
    StateProvince(code: 'AG', name: 'Aguascalientes'),
    StateProvince(code: 'BC', name: 'Baja California'),
    StateProvince(code: 'BS', name: 'Baja California Sur'),
    StateProvince(code: 'CM', name: 'Campeche'),
    StateProvince(code: 'CS', name: 'Chiapas'),
    StateProvince(code: 'CH', name: 'Chihuahua'),
    StateProvince(code: 'CO', name: 'Coahuila'),
    StateProvince(code: 'CL', name: 'Colima'),
    StateProvince(code: 'DF', name: 'Distrito Federal'),
    StateProvince(code: 'DG', name: 'Durango'),
    StateProvince(code: 'GT', name: 'Guanajuato'),
    StateProvince(code: 'GR', name: 'Guerrero'),
    StateProvince(code: 'HG', name: 'Hidalgo'),
    StateProvince(code: 'JA', name: 'Jalisco'),
    StateProvince(code: 'ME', name: 'México'),
    StateProvince(code: 'MI', name: 'Michoacán'),
    StateProvince(code: 'MO', name: 'Morelos'),
    StateProvince(code: 'NA', name: 'Nayarit'),
    StateProvince(code: 'NL', name: 'Nuevo León'),
    StateProvince(code: 'OA', name: 'Oaxaca'),
    StateProvince(code: 'PU', name: 'Puebla'),
    StateProvince(code: 'QT', name: 'Querétaro'),
    StateProvince(code: 'QR', name: 'Quintana Roo'),
    StateProvince(code: 'SL', name: 'San Luis Potosí'),
    StateProvince(code: 'SI', name: 'Sinaloa'),
    StateProvince(code: 'SO', name: 'Sonora'),
    StateProvince(code: 'TB', name: 'Tabasco'),
    StateProvince(code: 'TM', name: 'Tamaulipas'),
    StateProvince(code: 'TL', name: 'Tlaxcala'),
    StateProvince(code: 'VE', name: 'Veracruz'),
    StateProvince(code: 'YU', name: 'Yucatán'),
    StateProvince(code: 'ZA', name: 'Zacatecas'),
  ];

  /// Get states/provinces for a given country code
  static List<StateProvince> getStatesForCountry(String? countryCode) {
    if (countryCode == null || countryCode.toUpperCase() == 'OTHER') {
      return [];
    }
    
    switch (countryCode.toUpperCase()) {
      case 'US':
        return usStates;
      case 'CA':
        return canadianProvinces;
      case 'MX':
        return mexicanStates;
      default:
        return [];
    }
  }

  /// Get country by code
  static Country? getCountryByCode(String? code) {
    if (code == null) return null;
    try {
      return countries.firstWhere(
        (country) => country.code.toUpperCase() == code.toUpperCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get state by code for a country
  static StateProvince? getStateByCode(String? countryCode, String? stateCode) {
    if (countryCode == null || stateCode == null) return null;
    final states = getStatesForCountry(countryCode);
    try {
      return states.firstWhere(
        (state) => state.code.toUpperCase() == stateCode.toUpperCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Filter countries by search query
  static List<Country> filterCountries(String query) {
    if (query.isEmpty) return countries;
    final lowerQuery = query.toLowerCase();
    return countries.where((country) {
      return country.name.toLowerCase().contains(lowerQuery) ||
             country.code.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Filter states by search query
  static List<StateProvince> filterStates(String? countryCode, String query) {
    if (query.isEmpty) return getStatesForCountry(countryCode);
    final states = getStatesForCountry(countryCode);
    final lowerQuery = query.toLowerCase();
    return states.where((state) {
      return state.name.toLowerCase().contains(lowerQuery) ||
             state.code.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}

/// Country model
class Country {
  final String code; // ISO country code (e.g., 'US', 'CA')
  final String name; // Full country name

  const Country({
    required this.code,
    required this.name,
  });

  @override
  String toString() => name;
}

/// State/Province model
class StateProvince {
  final String code; // State/province code (e.g., 'FL', 'ON')
  final String name; // Full state/province name

  const StateProvince({
    required this.code,
    required this.name,
  });

  @override
  String toString() => name;
}
