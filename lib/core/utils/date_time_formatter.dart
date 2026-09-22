import 'package:intl/intl.dart';

abstract final class AppDates {
  static String day(DateTime utc, String locale) =>
      DateFormat.yMMMMEEEEd(locale).format(utc.toLocal());
  static String time(DateTime utc, String locale) =>
      DateFormat.jm(locale).format(utc.toLocal());
}
