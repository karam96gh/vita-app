# تجهيز الإصدار الإنتاجي

هذا الملف يحدد القيم الخارجية المطلوبة لإخراج نسخة قابلة للنشر. لا تُحفظ أي مفاتيح أو شهادات في Git.

## Firebase والإشعارات

1. في مشروع Firebase `vita-app-f54b5` سجّل ثلاثة تطبيقات Android بمعرّفات `com.vita.vita_patient.dev` و`com.vita.vita_patient.staging` و`com.vita.vita_patient`، وسجّل تطبيق iOS بالـ Bundle ID النهائي.
2. فعّل Cloud Messaging، وارفع APNs Authentication Key أو شهادة APNs في Firebase.
3. أنشئ ملف إعداد محلي لكل بيئة من `config/*.example.json`، واضبط `FIREBASE_ENABLED=true` والقيم `FIREBASE_APP_ID`, `FIREBASE_API_KEY`, `FIREBASE_MESSAGING_SENDER_ID` و`IOS_BUNDLE_ID`.
4. ابنِ التطبيق على جهاز فعلي واختبر foreground/background/terminated، ثم اختبار تسجيل الخروج وتبديل الحساب. لا تعتبر وصول التوكن وحده دليلاً على وصول الإشعار.

## Android

أنشئ keystore خارج المستودع، ثم ضع `android/key.properties` محلياً:

```properties
storeFile=release-upload.jks
storePassword=...
keyAlias=vita-upload
keyPassword=...
```

نفّذ:

```powershell
flutter build appbundle --release --flavor production --dart-define-from-file=config/production.local.json
```

ارفع الـ AAB إلى Google Play باستخدام Play App Signing، واحتفظ بنسخة من keystore وبيانات الاسترداد خارج Git.

## iOS

على macOS: ثبّت CocoaPods، افتح `ios/Runner.xcworkspace`، اضبط Team وBundle ID وشهادات Distribution وAPNs، ثم نفّذ `pod install` و`flutter build ipa --release --dart-define-from-file=config/production.local.json`. يجب رفع ملف `GoogleService-Info.plist` المطابق للـ Bundle ID إلى `ios/Runner/` محلياً فقط.

## حذف الحساب والخصوصية

قبل النشر يجب أن يوفر الـ API مسار حذف حساب موثقاً، مع تأكيد صريح من المستخدم، وإبطال الأجهزة والجلسات وحذف أو إخفاء البيانات وفق سياسة الاحتفاظ. لا يضيف التطبيق مساراً تخمينياً؛ عدّل المستودع بعد استلام المسار والعقد الرسميين.

انشر `docs/privacy-policy.md` على رابط HTTPS عام، وضع الرابط نفسه في متاجر Google Play وApp Store وداخل صفحة المتجر. راجع النص مع المسؤول القانوني قبل النشر.
