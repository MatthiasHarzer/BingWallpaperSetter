import 'dart:io';

// Assuming a file in the format wallpaper_yyyy-MM-dd_local_resolution
// where local in format en_GB and resolution 1920x1080

extension CustomFile on FileSystemEntity{
  String get name => uri.pathSegments.last;
  String get nameWithoutEnding => name.split(".").first;
  String? get stringDate => nameWithoutEnding.split("_").elementAt(1);
  DateTime? get date => DateTime.tryParse(stringDate.toString());
  String? get hsh => nameWithoutEnding.split("_").elementAt(2);
  String? get resolution => nameWithoutEnding.split("_").elementAt(3);
}