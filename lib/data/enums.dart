enum BeanType { singleOrigin, blend }

enum RoastLevel { light, lightMedium, medium, mediumDark, dark }

enum Process { washed, natural, honey, anaerobic, other }

extension BeanTypeLabel on BeanType {
  String get label => switch (this) {
        BeanType.singleOrigin => '싱글 오리진',
        BeanType.blend => '블렌드',
      };
}

extension RoastLevelLabel on RoastLevel {
  String get label => switch (this) {
        RoastLevel.light => '라이트',
        RoastLevel.lightMedium => '라이트미디엄',
        RoastLevel.medium => '미디엄',
        RoastLevel.mediumDark => '미디엄다크',
        RoastLevel.dark => '다크',
      };
}

extension ProcessLabel on Process {
  String get label => switch (this) {
        Process.washed => '워시드',
        Process.natural => '내추럴',
        Process.honey => '허니',
        Process.anaerobic => '무산소',
        Process.other => '기타',
      };
}
