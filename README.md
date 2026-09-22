# Vita — تطبيق المريض

تطبيق Flutter عربي RTL مع دعم الإنجليزية، وواجهات المواعيد والجلسات والتمارين والتقدّم والشات والتقييم والإشعارات.

**الحالة:** المصادقة والمواعيد والملف الشخصي والتقدّم وصندوق الإشعارات مرتبطة باستجابات API الفعلية. الجلسات والتمارين والمحادثة مع معالج والتقييم تحتاج استكمال العقد والبيانات الموضحة في [تقرير التنفيذ](docs/implementation-status.md). لا توجد بيانات تجريبية في التطبيق. إعداد Firebase والتوقيع ومتطلبات الإصدار الإنتاجي ما زالت قيد الاستكمال.

تم تحديث [APK للتجربة](build/app/outputs/flutter-apk/app-development-debug.apk) واختبار الملف والتقدّم والإشعارات على LDPlayer. نجح `flutter analyze` و17 اختباراً. حزمة AAB السابقة لا تشمل هذه التحديثات. ملفات البناء لا تعني اكتمال الربط أو جاهزية النشر.

## التشغيل

المتطلبات: Flutter stable متوافق مع Dart 3.11.5 أو أحدث، وAndroid SDK/JDK. بناء iOS يتطلب macOS وXcode.

```powershell
flutter pub get
Copy-Item config/development.example.json config/development.local.json
flutter run --flavor development --dart-define-from-file=config/development.local.json
```

ملف التطوير يستخدم عنوان `https://system.vitaxirpro.com` الذي حدده المستخدم، ويضيف التطبيق المسار `/api/v1/patient-app` تلقائياً. ملفات staging وproduction تحتاج عنوان HTTPS معتمداً لكل بيئة. لا تضع كلمات مرور أو توكنات في ملفات الإعداد.

تشغيل التطبيق دون إعداد gateway يعرض رسالة عدم توفر خدمة العيادة ولا يحاول تسجيل دخول وهمياً.

## الاختبارات والبناء

```powershell
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build appbundle --release --flavor production --dart-define-from-file=config/production.local.json
```

لتوقيع Android ضع `android/key.properties` محلياً مع `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. مسار المخزن يُحل نسبة إلى `android/app`. لا يُستخدم مفتاح debug لتوقيع release؛ غياب بيانات التوقيع ينتج حزمة غير موقعة إن اكتمل البناء.

## Firebase

المشروع المطلوب: `vita-xir`. اضبط `FIREBASE_ENABLED` على `true` وأضف خيارات التطبيق المسجل لكل منصة وبيئة: `FIREBASE_APP_ID`, `FIREBASE_API_KEY`, `FIREBASE_MESSAGING_SENDER_ID` و`IOS_BUNDLE_ID` عند الحاجة. هذه خيارات عميل Firebase؛ لا تستخدم ملف service account أو مفتاحاً إدارياً في التطبيق.

يمكن أيضاً إكمال إعداد FlutterFire الأصلي مع ملفات المنصة الصحيحة. يلزم تفعيل Push Notifications وAPNs في Xcode/Firebase. التهيئة وحدها لا تثبت وصول الإشعارات؛ يلزم اختبار جهاز فعلي. فتح الإشعار يوجّه إلى صندوق الإشعارات حتى يُوثّق payload التنقل.

## الملفات الرئيسية

- `lib/app`: التشغيل والتنقل والبيئات واللغة والتصميم.
- `lib/core`: الاتصال والأخطاء والتخزين الآمن ودورة حياة الخدمات.
- `lib/features`: الشاشات، والنماذج ومستودع بيانات المريض.
- `test`: اختبارات الشبكة وقواعد المجال والواجهات.
- [نواقص عقد API](docs/api-contract-gaps.md).
- [حالة التنفيذ والربط](docs/implementation-status.md).
- [قائمة جاهزية النشر](docs/release-readiness.md).

لا يمكن اعتبار التطبيق جاهزاً للمتاجر قبل استكمال البنود المفتوحة، وتوقيع الإصدار، واختبارات التكامل والأجهزة الفعلية.
