# BeanProfile 구현 로드맵 (v1)

각 마일스톤은 **그 자체로 동작하고 검증 가능한 증분**이다. 앞 단계가 확정된 뒤 다음 단계를 상세화한다.
관련 문서: 설계 [`../design.md`](../design.md) · 목업 [`../mockups/ui-mockup-v1.html`](../mockups/ui-mockup-v1.html) · 배포 [`../deployment.md`](../deployment.md)

| # | 마일스톤 | 완료 시 동작하는 것 | 상세 계획 |
|---|---|---|---|
| **M0** | 배포 파이프라인 | GitHub public 저장소 · `flutter create` · `release.yml` → **`v0.0.1` 태그로 hello world가 아이폰에 설치·실행됨**(무료 Apple ID + AltStore, **iOS 전용**; Android는 이후 이관) | [`milestone-0-delivery.md`](milestone-0-delivery.md) ✅ · 설계 [`../deployment.md`](../deployment.md) |
| **M1** | 기반 & 원두 추가/조회 | 테마/3탭 셸 · drift DB(3테이블) · 원두 **수동 추가 → 리스트 → 상세(읽기)** (Task 1 스캐폴드는 M0로 이관) | [`milestone-1-foundation.md`](milestone-1-foundation.md) ✅ 작성됨 |
| **M2** | 원두 편집/삭제 & 시음 기록 | 원두 편집·삭제 · **시음 입력**(강도 4축 + 종합 별점 + 코멘트) · 상세에 시음 리스트 · 평균 별점 계산 | 착수 직전 작성 |
| **M3** | 사진 & OCR 리뷰 | 촬영/갤러리 · ML Kit 온디바이스 인식 · **OCR 리뷰 화면**(자동 필드 + 배정 칩) · 추가 플로우에 연결 | 착수 직전 작성 |
| **M4** | 취향 대시보드 | 분석 쿼리 · **선호 강도 레이더 + 원산지·컵노트·가공방식 막대**(취향 탭) | 착수 직전 작성 |
| **M5** | 백업 & 마무리 | **JSON 내보내기/가져오기** · 설정 화면 · 원두 검색/정렬 · 빈 상태 · 앱 아이콘 | 착수 직전 작성 |

## 원칙

- **TDD:** 각 태스크는 실패하는 테스트 → 최소 구현 → 통과 → 커밋.
- **DRY / YAGNI:** v1 스코프(설계 §8) 밖 기능은 만들지 않는다.
- **잦은 커밋:** 태스크 단위로 커밋.
- **오프라인·로컬 전용:** 네트워크 권한 없음, 모든 데이터는 기기 내 drift(SQLite).
- **한국어 UI:** 사용자 노출 문자열은 모두 한국어.
- **테스트 규약:** 3계층 자동화 테스트 + 공유 헬퍼 + CI. 상세는 [`../testing.md`](../testing.md). 모든 마일스톤이 따른다.
- **배포 규약:** `v*` 태그 푸시로 폰에 전달. **현재(무료 결정): iOS 전용 — CI가 미서명 `.ipa`를 GitHub Release에 올리고 AltStore로 설치**(7일 갱신, PC+WiFi 필요). 향후 유료 전환 시 iOS(TestFlight)+Android APK 자동화로 승격 — 참조 스펙 [`../deployment.md`](../deployment.md), M0 상세 [`milestone-0-delivery.md`](milestone-0-delivery.md).

## 데이터 모델 (전 마일스톤 공통)

`Bean 1—N OriginComponent`(싱글=1, 블렌드=N) · `Bean 1—N Tasting`.
평가: 강도 `acidity/sweetness/body/bitterness` 1~5 + `overall` 1~5 + `comment`.
