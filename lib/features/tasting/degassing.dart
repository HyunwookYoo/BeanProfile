/// 시음 카드·폼에 띄울 디개싱 표시. 띄울 게 없으면 null.
///
/// 로스팅 날짜가 있으면 시음일과의 차이가 이기고, 없으면 사용자가 적은 값을 쓴다.
/// 기준은 오늘이 아니라 시음일이라, 지난 기록을 다시 열어도 숫자가 흔들리지 않는다.
({String text, bool warn})? degassingLabel({
  DateTime? roastDate,
  required DateTime tastingDate,
  int? manualDays,
}) {
  final days = roastDate != null ? _dayDiff(roastDate, tastingDate) : manualDays;
  if (days == null) return null;
  if (days < 0) return (text: '날짜 확인', warn: true);
  if (days == 0) return (text: '당일', warn: false);
  return (text: '디개싱 $days일', warn: false);
}

// 로컬 DateTime끼리 빼면 서머타임 경계에서 23시간이 나와 .inDays가 하루 틀린다.
// 두 날짜를 UTC 자정으로 정규화하면 차이가 항상 정확한 일수의 배수다.
int _dayDiff(DateTime roast, DateTime tasting) =>
    DateTime.utc(tasting.year, tasting.month, tasting.day)
        .difference(DateTime.utc(roast.year, roast.month, roast.day))
        .inDays;
