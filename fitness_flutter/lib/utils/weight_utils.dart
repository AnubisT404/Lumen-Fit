const double kgToLb = 2.20462;

double? kgToDisplay(double? kg, String unit) {
  if (kg == null) return null;
  if (unit == 'lb') return double.parse((kg * kgToLb).toStringAsFixed(1));
  return double.parse(kg.toStringAsFixed(1));
}

double displayToKg(double value, String unit) {
  if (unit == 'lb') return double.parse((value / kgToLb).toStringAsFixed(2));
  return value;
}

double weightIncrement(String unit) => unit == 'lb' ? 2.5 : 1;
