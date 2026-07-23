/// Parses a weight string like "500g", "1.5kg", "500ml", "1L"
/// and returns a record with the numeric value and sub-unit.
///
/// Examples:
///   parseWeight("500g")  → (500.0, "g")
///   parseWeight("1.5kg") → (1.5, "kg")
///   parseWeight("500ml") → (500.0, "ml")
///   parseWeight("1L")    → (1.0, "l")
///   parseWeight("")      → (0.0, "")
({double value, String subUnit}) parseWeight(String weight) {
  weight = weight.trim().toLowerCase();
  if (weight.isEmpty) return (value: 0, subUnit: '');

  const subUnits = ['kg', 'g', 'ml', 'l', 'ltr', 'liter', 'liters'];

  for (final su in subUnits) {
    if (weight.endsWith(su)) {
      final numStr = weight.substring(0, weight.length - su.length).trim();
      if (numStr.isEmpty) return (value: 0, subUnit: '');
      final val = double.tryParse(numStr);
      if (val == null) return (value: 0, subUnit: '');
      return (value: val, subUnit: su);
    }
  }

  return (value: 0, subUnit: '');
}

/// Normalizes variant sub-units to canonical base forms.
String _normalizeSubUnit(String sub) {
  switch (sub) {
    case 'l':
    case 'ltr':
    case 'liter':
    case 'liters':
      return 'l';
    default:
      return sub;
  }
}

/// Normalizes the product's unit field to canonical base forms.
String _normalizeBaseUnit(String unit) {
  switch (unit.trim().toLowerCase()) {
    case 'kg':
      return 'kg';
    case 'g':
      return 'g';
    case 'liters':
    case 'liter':
    case 'ltr':
    case 'l':
      return 'l';
    case 'ml':
      return 'ml';
    case 'pieces':
    case 'piece':
    case 'pcs':
    case 'pc':
    case 'units':
    case 'unit':
    case 'nos':
      return 'pieces';
    default:
      return unit.trim().toLowerCase();
  }
}

/// Computes the effective price for a product variant based on its
/// per-unit price and the actual weight/size.
///
/// The product's price field stores the cost per base unit (e.g., ₹120/kg).
/// The weight field describes the specific variant (e.g., "500g").
/// This function returns the effective price for that variant.
///
/// Examples:
///   calculateEffectivePrice(120, "500g", "kg")    → 60.00
///   calculateEffectivePrice(120, "1kg", "kg")     → 120.00
///   calculateEffectivePrice(120, "1.5kg", "kg")   → 180.00
///   calculateEffectivePrice(40, "500ml", "liters") → 20.00
///   calculateEffectivePrice(10, "", "pieces")       → 10.00
///   calculateEffectivePrice(10, "", "")             → 10.00
double calculateEffectivePrice(
    double pricePerUnit, String weight, String unit) {
  if (pricePerUnit <= 0) return pricePerUnit;

  final baseUnit = _normalizeBaseUnit(unit);

  // For pieces or empty/unknown units, no weight conversion applies
  if (baseUnit == 'pieces' || baseUnit.isEmpty) return pricePerUnit;

  final parsed = parseWeight(weight);
  final weightVal = parsed.value;
  final subUnit = parsed.subUnit;

  if (weightVal <= 0 || subUnit.isEmpty) return pricePerUnit;

  final normSub = _normalizeSubUnit(subUnit);

  // Convert the sub-unit value to the base unit
  double factor;
  switch (baseUnit) {
    case 'kg':
      if (normSub == 'g') {
        factor = weightVal / 1000.0;
      } else if (normSub == 'kg') {
        factor = weightVal;
      } else {
        return pricePerUnit;
      }
      break;
    case 'l':
      if (normSub == 'ml') {
        factor = weightVal / 1000.0;
      } else if (normSub == 'l') {
        factor = weightVal;
      } else {
        return pricePerUnit;
      }
      break;
    default:
      return pricePerUnit;
  }

  final result = pricePerUnit * factor;
  return (result * 100).roundToDouble() / 100; // round to 2 decimal places
}
