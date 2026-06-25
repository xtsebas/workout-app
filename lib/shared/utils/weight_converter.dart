const _kgToLbs = 2.20462;

double toDisplay(double kg, String unit) =>
    unit == 'lbs' ? kg * _kgToLbs : kg;

double toKg(double input, String unit) =>
    unit == 'lbs' ? input / _kgToLbs : input;

String fmtWeight(double? kg, String unit) {
  if (kg == null) return '';
  final v = toDisplay(kg, unit);
  return v % 1 == 0 ? '${v.toInt()}' : v.toStringAsFixed(1);
}

String weightUnit(String unit) => unit;
