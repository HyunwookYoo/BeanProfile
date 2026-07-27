import 'package:beanprofile/features/tasting/degassing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('로스팅 날짜가 있으면 시음일과의 차이를 쓴다', () {
    test('8일 차이', () {
      final r = degassingLabel(
          roastDate: DateTime(2026, 7, 19), tastingDate: DateTime(2026, 7, 27));
      expect(r?.text, '디개싱 8일');
      expect(r?.warn, isFalse);
    });

    test('같은 날이면 당일', () {
      final r = degassingLabel(
          roastDate: DateTime(2026, 7, 19), tastingDate: DateTime(2026, 7, 19));
      expect(r?.text, '당일');
      expect(r?.warn, isFalse);
    });

    test('시음일이 앞서면 날짜 확인', () {
      final r = degassingLabel(
          roastDate: DateTime(2026, 7, 19), tastingDate: DateTime(2026, 7, 15));
      expect(r?.text, '날짜 확인');
      expect(r?.warn, isTrue);
    });

    test('큰 값도 자르지 않는다', () {
      final r = degassingLabel(
          roastDate: DateTime(2026, 1, 1), tastingDate: DateTime(2026, 7, 27));
      expect(r?.text, '디개싱 207일');
    });

    test('수동 입력값이 있어도 계산값이 이긴다', () {
      final r = degassingLabel(
          roastDate: DateTime(2026, 7, 19),
          tastingDate: DateTime(2026, 7, 27),
          manualDays: 99);
      expect(r?.text, '디개싱 8일', reason: '로스팅 날짜가 사실이고 입력값은 대역이다');
    });
  });

  group('로스팅 날짜가 없으면 입력값을 쓴다', () {
    test('입력 8', () {
      final r = degassingLabel(tastingDate: DateTime(2026, 7, 27), manualDays: 8);
      expect(r?.text, '디개싱 8일');
      expect(r?.warn, isFalse);
    });

    test('입력 0은 당일', () {
      final r = degassingLabel(tastingDate: DateTime(2026, 7, 27), manualDays: 0);
      expect(r?.text, '당일');
    });

    test('둘 다 없으면 null', () {
      expect(degassingLabel(tastingDate: DateTime(2026, 7, 27)), isNull);
    });
  });

  test('시각이 섞여도 날짜 차이만 센다', () {
    // 시음 폼의 _date는 DateTime.now()라 시각이 붙어 있고,
    // roastDate는 날짜 선택기에서 와 자정이다. 정규화하지 않으면 하루가 틀어진다.
    final r = degassingLabel(
      roastDate: DateTime(2026, 7, 19, 0, 0),
      tastingDate: DateTime(2026, 7, 27, 23, 30),
    );
    expect(r?.text, '디개싱 8일', reason: '23:30이라고 9일이 되면 안 된다');

    final back = degassingLabel(
      roastDate: DateTime(2026, 7, 19, 23, 30),
      tastingDate: DateTime(2026, 7, 27, 0, 0),
    );
    expect(back?.text, '디개싱 8일', reason: '반대 방향도 마찬가지로 8일이다');
  });
}
