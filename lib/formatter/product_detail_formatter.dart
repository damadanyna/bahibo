const Map<String, String> productConditionOptions = {
  'OCCASION': 'Occasion',
  'RECONDITIONNE': 'Reconditionne',
  'NEUF': 'Neuf',
};

const Map<String, String> warrantyDurationUnitOptions = {
  'DAYS': 'Jours',
  'MONTHS': 'Mois',
  'YEARS': 'Annee',
};

String? productConditionLabelFromApi(dynamic apiValue) {
  final key = apiValue?.toString().trim().toUpperCase() ?? '';
  return productConditionOptions[key];
}

String productConditionApiFromLabel(String label) {
  return productConditionOptions.entries
      .firstWhere(
        (entry) => entry.value == label,
        orElse: () => const MapEntry('NEUF', 'Neuf'),
      )
      .key;
}

String? warrantyDurationUnitLabelFromApi(dynamic apiValue) {
  final key = apiValue?.toString().trim().toUpperCase() ?? '';
  return warrantyDurationUnitOptions[key];
}

String warrantyDurationUnitApiFromLabel(String label) {
  return warrantyDurationUnitOptions.entries
      .firstWhere(
        (entry) => entry.value == label,
        orElse: () => const MapEntry('MONTHS', 'Mois'),
      )
      .key;
}

/// Display value for the "État" detail row, or null when the product
/// predates this field (hide the row rather than assert a false state).
String? productConditionDisplayValue(Map<String, dynamic> product) {
  return productConditionLabelFromApi(product['condition']);
}

/// Display value for the "Garantie" detail row, or null when the product
/// has no warranty (hide the row) or the duration/unit is incomplete.
String? productWarrantyDisplayValue(Map<String, dynamic> product) {
  if (product['hasWarranty'] != true) {
    return null;
  }

  final rawValue = product['warrantyDurationValue'];
  final numericValue = rawValue is num
      ? rawValue.toInt()
      : int.tryParse('$rawValue');
  final unitApi = product['warrantyDurationUnit']?.toString().trim().toUpperCase() ?? '';
  if (numericValue == null || numericValue <= 0 || unitApi.isEmpty) {
    return null;
  }

  final unitText = switch (unitApi) {
    'DAYS' => numericValue == 1 ? 'Jour' : 'Jours',
    'MONTHS' => 'Mois',
    'YEARS' => numericValue == 1 ? 'Annee' : 'Annees',
    _ => null,
  };
  if (unitText == null) {
    return null;
  }

  return '$numericValue $unitText';
}
