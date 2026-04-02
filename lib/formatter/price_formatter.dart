String formatPriceAmount(num amount) {
  return amount
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]} ',
      );
}

String resolveProductCurrency(Map<String, dynamic> product) {
  final currency = product['currency'] ?? product['currencyCode'];
  if (currency is String && currency.trim().isNotEmpty) {
    return currency.trim();
  }
  return 'MGA';
}
