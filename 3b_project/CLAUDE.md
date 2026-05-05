# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

냉장고 요리사 - AI 기반 냉장고 관리 및 레시피 추천 앱 (졸업작품)

- **백엔드**: Spring Boot 3.2.3 (Java), Oracle DB, Gemini API, YouTube Data API v3
- **프론트엔드**: Flutter (Dart), flutter_local_notifications, url_launcher
- **인증**: Spring Security + JWT (jjwt 0.11.5)

## 환경 설정

### Java / Maven
- JDK: Amazon Corretto 25 (`C:\Program Files\Amazon Corretto\jdk25.0.2_10`)
- Maven: `C:\maven\apache-maven-3.9.6\bin\mvn.cmd`
- **주의**: Java 25 + Lombok 비호환 문제 있음 → pom.xml에 `lombok.version=1.18.36` 및 annotationProcessorPaths 명시 필요
- JAVA_HOME 설정 필요: `C:\Program Files\Amazon Corretto\jdk25.0.2_10`

### Oracle DB
- Oracle XE 21.3 설치파일: `C:\Users\gw604\Downloads\OracleXE213\setup.exe` (관리자 권한으로 실행)
- 설치 후 비밀번호: `Oracle21c!`, 포트: 1521
- DB 스키마: `database/01_create_tables.sql` → `database/02_sample_data.sql` 순서로 실행

### API 키
- Gemini API 키는 `application.properties`의 `gemini.api.key`에 설정됨
- YouTube API 키: `youtube.api.key` (미입력 시 레시피 영상 링크 비활성화)

## 빌드 및 실행

### 백엔드
```bash
cd server

# 컴파일
JAVA_HOME="C:/Program Files/Amazon Corretto/jdk25.0.2_10" \
  "C:/maven/apache-maven-3.9.6/bin/mvn.cmd" compile

# 실행 (Oracle DB 실행 중이어야 함)
JAVA_HOME="C:/Program Files/Amazon Corretto/jdk25.0.2_10" \
  "C:/maven/apache-maven-3.9.6/bin/mvn.cmd" spring-boot:run

# 패키징
"C:/maven/apache-maven-3.9.6/bin/mvn.cmd" package -DskipTests
```

### 프론트엔드
```bash
cd app

# 패키지 설치
flutter pub get

# Android 플랫폼 초기화 (최초 1회, android/ 디렉토리 없을 때)
flutter create . --platforms=android,ios

# 실행 (연결된 기기 선택)
flutter run                    # 기기 선택
flutter run -d chrome          # 크롬
flutter run -d windows         # Windows 데스크탑
```

## 아키텍처

### 백엔드 요청 흐름
```
HTTP 요청
  → JwtAuthenticationFilter (Bearer 토큰 검증)
  → SecurityConfig (인증/인가 판단, /api/auth/** 는 permitAll)
  → Controller (@CrossOrigin 적용)
  → Service (비즈니스 로직)
  → Repository (JPA → Oracle)
```

### AI 처리 흐름 (핵심)
1. **이미지 스캔**: `POST /api/scan/analyze` → `GeminiVisionService.analyzeImage()` → Base64 변환 → Gemini Vision API → 재료명 목록 반환 (DB 저장 안 함)
2. **재료 확정 저장**: Flutter에서 사용자가 검토 후 `POST /api/ingredients/user/{id}/batch` 호출
3. **레시피 추천**: `POST /api/recipes/recommend/{userId}` → `RecipeService.recommendRecipes()` → 보유 재료로 Gemini 텍스트 API 호출 → YouTube API 검색 → RECIPES 테이블 저장

### Flutter 화면 흐름
```
SplashScreen (자동 로그인 확인)
  ├─ LoginScreen → RegisterScreen
  └─ HomeScreen (BottomNavigation 4탭)
       ├─ IngredientScreen (냉장고 재료 CRUD, 슬라이드 삭제)
       ├─ ScanScreen (5단계: select→preview→analyzing→review→done)
       ├─ RecipeScreen (AI 추천 목록) → RecipeDetailScreen (YouTube 링크)
       └─ ProfileScreen
```

### ScanScreen 5단계 UX
`ScanStep` enum으로 상태 관리: `select → preview → analyzing → review → done`
- **review 단계**: `_IngredientItem` 리스트로 체크박스 선택/편집/삭제 가능
- 저장 시 `IngredientApiService.saveIngredientsBatch()` 호출 → 유통기한 있는 재료는 `NotificationService.scheduleExpiryAlert()` 자동 등록

### 알림 시스템
`NotificationService` (Flutter) - `flutter_local_notifications` + `timezone`:
- 앱 로그인 시: `/api/ingredients/user/{id}/expiring` 조회 → 즉시 알림
- 재료 추가 시: D-3, D-1 예약 알림 등록
- 매일 오전 9시: `matchDateTimeComponents: DateTimeComponents.time` 으로 반복 알림

## 주요 설정 파일

### `server/src/main/resources/application.properties`
- `spring.jpa.hibernate.ddl-auto=none` → Hibernate가 테이블 자동 생성 안 함, DB 스키마 수동 실행 필요
- `spring.datasource.url=jdbc:oracle:thin:@localhost:1521:XE`

### `app/lib/services/api_service.dart`
- `baseUrl = 'http://10.0.2.2:8080/api'` (Android 에뮬레이터 기준)
- 실제 기기 테스트 시 PC IP로 변경 필요

## API 엔드포인트 요약

| 인증 불필요 | 설명 |
|------------|------|
| `POST /api/auth/register` | 회원가입 |
| `POST /api/auth/login` | 로그인 → JWT 반환 |

| JWT 필요 (Authorization: Bearer {token}) | 설명 |
|------------------------------------------|------|
| `POST /api/scan/analyze` | 이미지 분석만 (저장 안 함) |
| `GET /api/ingredients/user/{id}` | 재료 목록 |
| `POST /api/ingredients/user/{id}/batch` | 재료 일괄 저장 (스캔 확정) |
| `GET /api/ingredients/user/{id}/expiring` | 3일 이내 만료 재료 |
| `POST /api/recipes/recommend/{id}` | AI 레시피 추천 |

## 알려진 이슈

- **Lombok + Java 25**: `TypeTag::UNKNOWN` 에러 발생 가능. pom.xml의 `annotationProcessorPaths` 확인
- **Oracle 미설치 시**: 백엔드 시작 불가. H2 인메모리 DB로 임시 전환 가능 (pom.xml에 H2 의존성 추가 + application.properties 수정)
- **Flutter Android 플랫폼**: `android/` 디렉토리 없으면 `flutter create . --platforms=android` 먼저 실행
- `android/app/src/main/AndroidManifest.xml`에 알림·카메라 권한 추가 필요 (`android_setup_guide.md` 참조)
