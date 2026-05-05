# Android 플랫폼 설정 가이드

flutter create . 또는 flutter pub get 실행 후 아래 설정을 추가하세요.

## 1. android/app/src/main/AndroidManifest.xml 수정

<manifest> 태그 바로 안에 추가:
```xml
<!-- 알림 권한 (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<!-- 정확한 알람 권한 (유통기한 예약 알림) -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<!-- 인터넷 권한 -->
<uses-permission android:name="android.permission.INTERNET"/>
<!-- 카메라 권한 -->
<uses-permission android:name="android.permission.CAMERA"/>
```

<activity> 태그 안에 추가 (url_launcher용):
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="https"/>
</intent-filter>
```

<application> 태그 안에 추가 (flutter_local_notifications용):
```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>
```

## 2. android/app/build.gradle 확인

minSdkVersion이 21 이상인지 확인:
```gradle
defaultConfig {
    minSdkVersion 21
    targetSdkVersion 34
}
```

## 3. 패키지 설치

프로젝트 루트(frontend/)에서:
```bash
flutter pub get
```

## 4. iOS 설정 (선택사항)

ios/Runner/Info.plist에 추가:
```xml
<key>NSCameraUsageDescription</key>
<string>냉장고 사진 촬영을 위해 카메라가 필요합니다.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>갤러리에서 냉장고 사진을 선택하기 위해 필요합니다.</string>
```
