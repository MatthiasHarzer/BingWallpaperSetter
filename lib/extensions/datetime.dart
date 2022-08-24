import 'package:intl/intl.dart';

const String _format = "yyyy-MM-dd";
final DateFormat _formatter = DateFormat(_format);

extension CustomDateTime on DateTime{
  /// The DateTime formatted to a string in format yyyy-MM-dd
  String get formatted => _formatter.format(this);

  /// The datetime with with time = 00:00.00
  DateTime get normalized => DateTime.parse(formatted);
}