# google_mlkit_text_recognition 플러그인은 네 문자 체계(중국어·데바나가리·일본어·한국어)의
# 옵션 클래스를 모두 참조하지만, 앱은 한국어 인식 모델만 의존성으로 넣는다(build.gradle.kts).
# 나머지 셋은 classpath에 없어 R8이 "Missing class"로 release 빌드를 멈춘다.
# 앱은 한국어 인식기만 만들므로(lib/services/ocr_service.dart) 런타임에 이 클래스들에 닿지 않는다.
# 모델 의존성을 더하면 앱이 수 MB씩 커지므로 경고만 끈다(docs/plans/android-play-release-design.md §5).
# Flutter Gradle 플러그인이 이 파일을 release 빌드의 R8 규칙에 자동으로 더한다.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
