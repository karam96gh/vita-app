import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../core/errors/api_failure.dart';

class AppStrings {
  const AppStrings(this.locale);
  final Locale locale;
  bool get ar => locale.languageCode == 'ar';
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings)!;
  String t(String key) {
    final pair = _copy[key] ?? _copy['UNKNOWN']!;
    return pair[ar ? 0 : 1];
  }

  String error(Object error) => t(error is ApiFailure ? error.code : 'UNKNOWN');
  static const delegate = _StringsDelegate();

  static const _copy = <String, List<String>>{
    'exerciseDescription': ['وصف التمرين', 'Description'],
    'exerciseInstructions': ['تعليمات المعالج', 'Therapist instructions'],
    'exerciseMethod': ['طريقة الأداء', 'How to perform'],
    'exerciseWarnings': ['تنبيهات', 'Warnings'],
    'exerciseMistakes': ['أخطاء شائعة', 'Common mistakes'],
    'exerciseFrequency': ['التكرار الموصى به', 'Frequency'],
    'exerciseDuration': ['المدة (ثانية)', 'Duration (seconds)'],
    'exerciseSets': ['المجموعات', 'Sets'],
    'exerciseReps': ['التكرارات', 'Repetitions'],
    'exerciseHold': ['الثبات (ثانية)', 'Hold (seconds)'],
    'exerciseRest': ['الراحة (ثانية)', 'Rest (seconds)'],
    'tagline': ['خطوة أقرب إلى العافية', 'One step closer to feeling better'],
    'welcome': ['أهلاً بك في ڤيتا', 'Welcome to Vita'],
    'welcomeBack': ['أهلاً بعودتك', 'Welcome back'],
    'loginHint': [
      'تابع رحلتك العلاجية، خطوة بخطوة.',
      'Continue your care journey, one step at a time.',
    ],
    'login': ['تسجيل الدخول', 'Sign in'],
    'register': ['إنشاء حساب', 'Create account'],
    'registerHint': [
      'استخدم رقم هاتفك المسجّل لدى العيادة.',
      'Use the phone number registered at your clinic.',
    ],
    'username': ['اسم المستخدم', 'Username'],
    'password': ['كلمة المرور', 'Password'],
    'phone': ['رقم الهاتف', 'Phone number'],
    'showPassword': ['إظهار كلمة المرور', 'Show password'],
    'hidePassword': ['إخفاء كلمة المرور', 'Hide password'],
    'newAccount': ['ليس لديك حساب؟ إنشاء حساب', 'New here? Create an account'],
    'existingAccount': [
      'لديك حساب؟ تسجيل الدخول',
      'Already registered? Sign in',
    ],
    'home': ['الرئيسية', 'Home'],
    'appointments': ['المواعيد', 'Appointments'],
    'sessions': ['جلساتي', 'My sessions'],
    'chat': ['المحادثة', 'Chat'],
    'profile': ['حسابي', 'Account'],
    'progress': ['تقدّمي', 'My progress'],
    'notifications': ['الإشعارات', 'Notifications'],
    'todayTitle': ['رحلتك نحو التعافي', 'Your recovery journey'],
    'todayHint': [
      'كل خطوة صغيرة تصنع فرقاً. تابع خطة معالجك من هنا.',
      'Every small step matters. Follow your therapist’s plan here.',
    ],
    'yourCare': ['رعايتك في مكان واحد', 'Your care, in one place'],
    'viewAll': ['عرض الكل', 'View all'],
    'nextAppointment': ['موعدك القادم', 'Your next appointment'],
    'exerciseHint': [
      'تمارينك وتعليمات معالجك',
      'Exercises and therapist instructions',
    ],
    'chatHint': [
      'تواصل مع معالجك المسؤول',
      'Talk with your assigned therapist',
    ],
    'progressHint': ['تابع ما أنجزته من تمارين', 'See your exercise progress'],
    'empty': ['لا توجد بيانات لعرضها حالياً', 'Nothing to display yet'],
    'emptyAppointments': ['لا توجد مواعيد حالياً', 'No appointments yet'],
    'emptyAppointmentsHint': [
      'ستظهر مواعيد العيادة هنا عند إضافتها.',
      'Your clinic appointments will appear here when scheduled.',
    ],
    'emptySessions': ['لا توجد جلسات حالياً', 'No sessions yet'],
    'emptyExercises': [
      'لا توجد تمارين لهذه الجلسة',
      'No exercises for this session',
    ],
    'emptyChat': [
      'ابدأ محادثتك مع معالجك',
      'Start a conversation with your therapist',
    ],
    'emptyNotifications': ['لا توجد إشعارات جديدة', 'No notifications yet'],
    'retry': ['إعادة المحاولة', 'Try again'],
    'loading': ['جارٍ التحميل', 'Loading'],
    'refresh': ['تحديث', 'Refresh'],
    'cancel': ['إلغاء', 'Cancel'],
    'confirm': ['تأكيد', 'Confirm'],
    'done': ['تم بنجاح', 'Done'],
    'logout': ['تسجيل الخروج', 'Sign out'],
    'logoutConfirm': [
      'هل تريد تسجيل الخروج من حسابك؟',
      'Sign out of your account?',
    ],
    'language': ['اللغة', 'Language'],
    'arabic': ['العربية', 'Arabic'],
    'english': ['الإنجليزية', 'English'],
    'carePlan': ['الخطة العلاجية', 'Care plan'],
    'session': ['جلسة علاج', 'Treatment session'],
    'exercises': ['التمارين', 'Exercises'],
    'instructions': ['تعليمات التمرين', 'Exercise instructions'],
    'exerciseDetails': ['تفاصيل إضافية', 'Additional details'],
    'startSession': ['ابدأ جلسة التمارين', 'Start exercise session'],
    'sessionDone': ['أنهيت جلستك', 'Session complete'],
    'sessionDoneHint': [
      'أحسنت! تابع خطتك في الجلسة القادمة.',
      'Well done. Continue your plan in the next session.',
    ],
    'timerLabel': ['متبقٍ', 'remaining'],
    'reset': ['إعادة ضبط', 'Reset'],
    'next': ['التالي', 'Next'],
    'close': ['إغلاق', 'Close'],
    'exerciseCompleted': ['تم إنجازه', 'Completed'],
    'exerciseSkipped': ['تم تخطيه', 'Skipped'],
    'actionsUnavailable': [
      'تنفيذ التمارين غير متاح حالياً. تواصل مع العيادة.',
      'Exercise actions are unavailable right now. Contact your clinic.',
    ],
    'doneLabel': ['منجز', 'done'],
    'todayProgressHint': [
      'من تمارين خطتك الحالية',
      'of your current plan\'s exercises',
    ],
    'start': ['بدء التمرين', 'Start exercise'],
    'complete': ['إكمال التمرين', 'Complete exercise'],
    'skip': ['تخطي التمرين', 'Skip exercise'],
    'cancelledExercise': ['ملغي', 'Cancelled'],
    'cancelledHint': [
      'ألغى المعالج هذا التمرين.',
      'Your therapist cancelled this exercise.',
    ],
    'note': ['ملاحظة اختيارية', 'Optional note'],
    'reason': ['سبب التخطي', 'Reason for skipping'],
    'reasonText': ['وضّح السبب', 'Explain the reason'],
    'completeConfirm': [
      'هل أكملت هذا التمرين؟',
      'Have you completed this exercise?',
    ],
    'active': ['الفعّالة', 'Active'],
    'completed': ['المكتملة', 'Completed'],
    'skipped': ['المتخطاة', 'Skipped'],
    'running': ['قيد التنفيذ', 'In progress'],
    'message': ['اكتب رسالتك', 'Write a message'],
    'send': ['إرسال', 'Send'],
    'therapist': ['معالجك المسؤول', 'Your therapist'],
    'chatPrivacy': [
      'محادثة خاصة مع المعالج المسؤول عنك',
      'A private conversation with your assigned therapist',
    ],
    'rate': ['تقييم الجلسة', 'Rate session'],
    'ratingTitle': ['كيف كانت جلستك؟', 'How was your session?'],
    'ratingPrivacy': [
      'التقييم سري ولا يظهر للمعالج. يمكن الاطلاع عليه فقط من قبل رئيس قسم العلاج الفيزيائي.',
      'Your rating is confidential and hidden from your therapist. Only the head of physiotherapy can view it.',
    ],
    'ratingThanks': ['شكراً لمشاركتك رأيك', 'Thank you for your feedback'],
    'privateNote': ['ملاحظة سرية اختيارية', 'Optional private note'],
    'submitRating': ['إرسال التقييم', 'Submit rating'],
    'read': ['مقروء', 'Read'],
    'markRead': ['تحديد كمقروء', 'Mark as read'],
    'enableNotifications': ['تفعيل الإشعارات', 'Enable notifications'],
    'notificationsEnabled': ['تم تفعيل الإشعارات', 'Notifications enabled'],
    'play': ['تشغيل', 'Play'],
    'pause': ['إيقاف مؤقت', 'Pause'],
    'mediaUnavailable': [
      'الوسائط غير متاحة حالياً',
      'Media is currently unavailable',
    ],
    'serviceUnavailable': [
      'الخدمة غير متاحة حالياً',
      'Service currently unavailable',
    ],
    'setupHint': [
      'تعذر الاتصال بخدمة العيادة. يرجى التواصل مع الدعم.',
      'The clinic service is not configured. Please contact support.',
    ],
    'REQUIRED': ['هذا الحقل مطلوب', 'This field is required'],
    'CONTRACT_REQUIRED': [
      'هذه الخدمة غير متاحة حالياً. يرجى المحاولة لاحقاً أو التواصل مع العيادة.',
      'This service is currently unavailable. Try later or contact your clinic.',
    ],
    'PATIENT_NOT_FOUND_IN_ERP': [
      'لم نجد مريضاً بهذا الرقم. تواصل مع العيادة أولاً.',
      'No patient matches this phone. Contact your clinic first.',
    ],
    'PATIENT_AMBIGUOUS_MATCH': [
      'يرجى التواصل مع العيادة للتحقق من رقم الهاتف.',
      'Contact your clinic to verify your phone number.',
    ],
    'PATIENT_ACCOUNT_EXISTS': [
      'لديك حساب بالفعل. يرجى تسجيل الدخول.',
      'An account already exists. Please sign in.',
    ],
    'USERNAME_TAKEN': [
      'اسم المستخدم مستخدم بالفعل.',
      'This username is already taken.',
    ],
    'PATIENT_ACCOUNT_INACTIVE': [
      'حسابك غير نشط. تواصل مع العيادة.',
      'Your account is inactive. Contact your clinic.',
    ],
    'INVALID_CREDENTIALS': [
      'اسم المستخدم أو كلمة المرور غير صحيحة.',
      'Incorrect username or password.',
    ],
    'AUTH_TOKEN_INVALID': [
      'انتهت الجلسة. يرجى تسجيل الدخول مجدداً.',
      'Your session expired. Please sign in again.',
    ],
    'SESSION_CHANGED': [
      'تغيرت جلسة الدخول. يرجى المحاولة مجدداً.',
      'Your sign-in session changed. Please try again.',
    ],
    'SESSION_NOT_FOUND': ['الجلسة غير موجودة.', 'Session not found.'],
    'EXERCISE_NOT_FOUND': ['التمرين غير موجود.', 'Exercise not found.'],
    'ASSIGNMENT_NOT_FOUND': [
      'التمرين المسند غير موجود.',
      'Assigned exercise not found.',
    ],
    'ASSIGNMENT_CANCELLED': [
      'أُلغي هذا التمرين ولا يمكن تنفيذه.',
      'This exercise was cancelled and cannot be performed.',
    ],
    'INVALID_ACTION': [
      'هذا الإجراء غير متاح لحالة التمرين الحالية.',
      'This action is unavailable for the current exercise state.',
    ],
    'SKIP_REASON_REQUIRED': [
      'اختر سبباً للتخطي.',
      'Choose a reason for skipping.',
    ],
    'SKIP_REASON_TEXT_REQUIRED': [
      'يرجى توضيح سبب التخطي.',
      'Please explain why you are skipping.',
    ],
    'INVALID_SKIP_REASON': [
      'سبب التخطي غير صالح. حدّث القائمة.',
      'This reason is no longer valid. Refresh the list.',
    ],
    'NO_RESPONSIBLE_THERAPIST': [
      'لا يوجد معالج مسؤول عنك حالياً',
      'No therapist is currently assigned to you.',
    ],
    'SESSION_NOT_COMPLETED': [
      'يمكن التقييم بعد تأكيد انتهاء الجلسة فقط.',
      'You can rate only after the session is confirmed complete.',
    ],
    'RATING_ALREADY_EXISTS': [
      'سبق أن قيّمت هذه الجلسة.',
      'You have already rated this session.',
    ],
    'FORBIDDEN': [
      'لا يمكنك الوصول إلى هذه البيانات.',
      'You do not have access to this information.',
    ],
    'OFFLINE': [
      'تعذر الاتصال. تحقق من اتصالك بالإنترنت.',
      'Unable to connect. Check your internet connection.',
    ],
    'TIMEOUT': [
      'استغرق الاتصال وقتاً طويلاً. حاول مجدداً.',
      'The connection timed out. Try again.',
    ],
    'RETRY_ACTION': [
      'تم تجديد الدخول. يرجى إعادة الإجراء.',
      'Your session was renewed. Please repeat the action.',
    ],
    'NETWORK_ERROR': [
      'تعذر إتمام الطلب. يرجى المحاولة مجدداً.',
      'Unable to complete the request. Please try again.',
    ],
    'INVALID_RESPONSE': [
      'تعذر تحميل البيانات. يرجى التواصل مع العيادة إن استمرت المشكلة.',
      'Unable to load data. Contact your clinic if this continues.',
    ],
    'PUSH_UNAVAILABLE': [
      'الإشعارات غير متاحة على هذا الجهاز حالياً.',
      'Notifications are currently unavailable on this device.',
    ],
    'PUSH_DENIED': [
      'يمكنك السماح بالإشعارات من إعدادات الجهاز.',
      'You can allow notifications in device settings.',
    ],
    'UNKNOWN': [
      'حدث خطأ. يرجى المحاولة مجدداً.',
      'Something went wrong. Please try again.',
    ],
  };
}

class _StringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _StringsDelegate();
  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);
  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(locale));
  @override
  bool shouldReload(_StringsDelegate old) => false;
}

extension StringsContext on BuildContext {
  AppStrings get strings => AppStrings.of(this);
  String t(String key) => strings.t(key);
}
