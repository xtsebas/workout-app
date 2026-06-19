enum SetType {
  straight,
  ascending,
  descending;

  String get label => switch (this) {
        straight => 'Straight',
        ascending => 'Pyramid Up',
        descending => 'Pyramid Down',
      };
}
