import 'dart:io';

extension CustomFile on FileSystemEntity{
  String get name => uri.pathSegments.last.split(".").first;
  String? get date => name.split("_").isNotEmpty ? name.split("_").last : null;
}