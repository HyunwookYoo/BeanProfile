import 'database.dart';
import 'enums.dart';

class ComponentInput {
  final String country;
  final String? region;
  final String? farm;
  final String? variety;
  final Process process;
  final String? altitude;
  final int? ratioPercent;
  const ComponentInput({
    required this.country,
    this.region,
    this.farm,
    this.variety,
    this.process = Process.washed,
    this.altitude,
    this.ratioPercent,
  });
}

class BeanInput {
  final String name;
  final String roaster;
  final BeanType type;
  final RoastLevel? roastLevel;
  final DateTime? roastDate;
  final List<String> cupNotes;
  final String? memo;
  final List<ComponentInput> components;
  const BeanInput({
    required this.name,
    required this.roaster,
    required this.type,
    required this.roastLevel,
    required this.roastDate,
    required this.cupNotes,
    required this.memo,
    required this.components,
  });
}

class BeanSummary {
  final Bean bean;
  final String? originLabel;
  final double? avgRating;
  final int tastingCount;
  const BeanSummary({
    required this.bean,
    required this.originLabel,
    required this.avgRating,
    required this.tastingCount,
  });
}

class BeanDetail {
  final Bean bean;
  final List<OriginComponent> components;
  final List<Tasting> tastings;
  const BeanDetail({
    required this.bean,
    required this.components,
    required this.tastings,
  });
}
