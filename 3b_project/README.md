# 🍳 냉장고 요리사 - AI 냉장고 관리 & 레시피 추천 앱

> 이 저장소는 3인 팀 프로젝트([원본 저장소](https://github.com/hyeji203/refrigerator-app))를
> 마친 뒤, 개인적으로 개선 작업을 이어간 저장소입니다.
> 개선 내역: 휴리스틱 평가 기반 UI 개선, 알레르기 맞춤 추천, 레시피 검색·자동 정리 등

## 📱 주요 기능
1. **AI 냉장고 스캔**: 냉장고 사진 촬영 → Gemini Vision AI가 재료 자동 인식 → DB 저장
2. **재료 관리**: 냉장고 재료 CRUD, 유통기한 입력
3. **AI 레시피 추천**: 보유 재료 기반 Gemini AI 레시피 생성 + YouTube 영상 링크
4. **유통기한 알람**: 유통기한 3일/1일 전 푸시 알림, 매일 오전 9시 리마인더

## 🛠 기술 스택
- **Backend**: Spring Boot 3.2.3 (Java 17), Spring Security + JWT, Oracle DB, Gemini AI, YouTube API
- **Frontend**: Flutter (Dart), flutter_local_notifications, url_launcher
- **AI**: Google Gemini 1.5 Flash (이미지 인식 + 레시피 생성)

---

## 🚀 실행 방법

### 1. API 키 발급
- [Google AI Studio](https://aistudio.google.com/) → Gemini API 키 발급
- [Google Cloud Console](https://console.cloud.google.com/) → YouTube Data API v3 키 발급

### 2. 백엔드 설정

`server/src/main/resources/application.properties` 수정:
```properties
# Oracle DB 연결 (Oracle XE 설치 후)
spring.datasource.url=jdbc:oracle:thin:@localhost:1521:XE
spring.datasource.username=your_db_username
spring.datasource.password=your_db_password

# JWT 시크릿 (32자 이상 랜덤 문자열)
jwt.secret=your-very-long-secret-key-must-be-at-least-256-bits

# API 키
gemini.api.key=YOUR_GEMINI_API_KEY
youtube.api.key=YOUR_YOUTUBE_API_KEY
```

DB 스키마 생성:
```sql
-- Oracle SQL Developer 또는 sqlplus에서 실행
@database/01_create_tables.sql
@database/02_sample_data.sql
```

백엔드 실행:
```bash
cd server
mvn spring-boot:run
```

### 3. 프론트엔드 설정

Android 플랫폼 초기화 (최초 1회):
```bash
cd app
flutter create . --platforms=android,ios
```

`app/android_setup_guide.md` 참고하여 AndroidManifest.xml 설정 후:
```bash
flutter pub get
flutter run
```

API 서버 주소 설정 (`lib/services/api_service.dart`):
```dart
// 에뮬레이터: http://10.0.2.2:8080/api
// 실제 기기: http://[PC의 IP주소]:8080/api
static const String baseUrl = 'http://10.0.2.2:8080/api';
```

---

## 📂 프로젝트 구조

```
3b프로젝트/
├── server/                          # Spring Boot 백엔드
│   └── src/main/java/com/refrigerator/app/
│       ├── controller/
│       │   ├── AuthController.java   # 로그인/회원가입 API
│       │   ├── IngredientController.java
│       │   ├── RecipeController.java
│       │   └── ScanController.java   # 냉장고 사진 스캔 API
│       ├── security/
│       │   ├── JwtUtil.java          # JWT 토큰 생성/검증
│       │   ├── JwtAuthenticationFilter.java
│       │   └── SecurityConfig.java
│       ├── service/
│       │   ├── AuthService.java      # 인증 비즈니스 로직
│       │   ├── IngredientService.java
│       │   ├── RecipeService.java    # Gemini + YouTube 연동
│       │   └── GeminiVisionService.java # 이미지 AI 인식
│       └── entity/ dto/ repository/
│
├── app/                         # Flutter 앱
│   └── lib/
│       ├── main.dart                 # 앱 진입점 + 스플래시 + 자동로그인
│       ├── screens/
│       │   ├── login_screen.dart
│       │   ├── register_screen.dart  # 회원가입 화면
│       │   ├── home_screen.dart      # 하단 탭 네비게이션
│       │   ├── ingredient_screen.dart # 냉장고 재료 목록
│       │   ├── scan_screen.dart      # AI 스캔 화면
│       │   ├── recipe_screen.dart    # 레시피 추천 목록
│       │   ├── recipe_detail_screen.dart # 레시피 상세 + YouTube
│       │   └── profile_screen.dart
│       └── services/
│           ├── api_service.dart      # Dio HTTP 클라이언트
│           ├── auth_service.dart     # 로그인/자동로그인/로그아웃
│           ├── ingredient_service.dart
│           └── notification_service.dart # 유통기한 알림 스케줄링
│
└── database/
    ├── 01_create_tables.sql          # Oracle DDL (8개 테이블)
    └── 02_sample_data.sql            # 테스트 데이터
```

---

## 🔔 알림 동작 방식

| 시점 | 알림 내용 |
|------|----------|
| 앱 로그인 시 | 유통기한 3일 이내 재료 즉시 알림 |
| 재료 추가 시 (유통기한 입력) | D-3, D-1 예약 알림 자동 등록 |
| 매일 오전 9시 | 냉장고 확인 리마인더 알림 |

## 📡 API 엔드포인트

| Method | URL | 설명 |
|--------|-----|------|
| POST | /api/auth/register | 회원가입 |
| POST | /api/auth/login | 로그인 |
| GET | /api/ingredients/user/{id} | 재료 목록 조회 |
| POST | /api/ingredients/user/{id} | 재료 추가 |
| PUT | /api/ingredients/{id} | 재료 수정 |
| DELETE | /api/ingredients/{id} | 재료 삭제 |
| GET | /api/ingredients/user/{id}/expiring | 유통기한 임박 재료 |
| POST | /api/scan/fridge/{userId} | 냉장고 사진 AI 스캔 |
| POST | /api/recipes/recommend/{userId} | AI 레시피 추천 |
| GET | /api/recipes/user/{userId} | 저장된 레시피 목록 |
| PATCH | /api/recipes/{id}/save | 레시피 즐겨찾기 토글 |
| DELETE | /api/recipes/{id} | 레시피 삭제 |
