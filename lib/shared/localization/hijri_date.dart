import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

const List<String> hijriMonthsAr = [
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
  'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
];

const List<String> hijriMonthsEn = [
  'Muharram', 'Safar', "Rabi' al-awwal", "Rabi' al-thani",
  'Jumada al-awwal', 'Jumada al-thani', 'Rajab', "Sha'ban",
  'Ramadan', 'Shawwal', "Dhu al-Qi'dah", 'Dhu al-Hijjah',
];

/// التاريخ الهجري المقابل لتاريخ ميلادي، مع اسم اليوم، بنفس لغة الواجهة.
/// نبني النص يدويًا (بدل استخدام HijriCalendar.format) عشان نضمن أرقامًا
/// غربية (Western digits) متناسقة مع باقي تنسيقات التطبيق.
String hijriDateString(DateTime date, String lang, {bool withWeekday = true}) {
  final hijri = HijriCalendar.fromDate(date);
  final months = lang == 'ar' ? hijriMonthsAr : hijriMonthsEn;
  final month = months[hijri.hMonth - 1];
  final suffix = lang == 'ar' ? 'هـ' : 'AH';
  final datePart = '${hijri.hDay} $month ${hijri.hYear} $suffix';
  if (!withWeekday) return datePart;
  final weekday = DateFormat('EEEE', lang).format(date);
  final separator = lang == 'ar' ? '، ' : ', ';
  return '$weekday$separator$datePart';
}

/// نسخة مختصرة بدون اسم اليوم — للأماكن الضيقة كنتائج البحث.
String hijriShortDateString(DateTime date, String lang) {
  final hijri = HijriCalendar.fromDate(date);
  final months = lang == 'ar' ? hijriMonthsAr : hijriMonthsEn;
  final month = months[hijri.hMonth - 1];
  return '${hijri.hDay} $month';
}
