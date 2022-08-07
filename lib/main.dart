import 'package:bing_wallpaper_setter/body.dart';
import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:bing_wallpaper_setter/services/wallpaper_service.dart';
import 'package:bing_wallpaper_setter/util/util.dart';
import 'package:bing_wallpaper_setter/views/about_view.dart';
import 'package:bing_wallpaper_setter/views/settings_view.dart';
import 'package:bing_wallpaper_setter/views/wallpaper_info_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

import 'drawer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ConfigService.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bing Daily Wallpaper',
      theme: ThemeData(
          switchTheme: SwitchThemeData(
            thumbColor: MaterialStateProperty.resolveWith((states) =>
                states.contains(MaterialState.selected)
                    ? Colors.deepPurpleAccent
                    : null),
            trackColor: MaterialStateProperty.resolveWith((states) =>
                states.contains(MaterialState.selected)
                    ? Colors.deepPurple[500]
                    : null),
          ),
          primarySwatch: Colors.deepPurple,

          brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  WallpaperInfo? wallpaper;

  @override
  void initState() {
    super.initState();

    _loadWallpaper();
    _checkPermission();
  }

  void _checkPermission() async {
    bool storagePermissionGranted = await _requestStoragePermission();

    if (!storagePermissionGranted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 10),
              child: const SizedBox(
                height: 10,
                width: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
            const Text(
              "No storage permission! The app might not work properly.",
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.grey.shade900,
        duration: const Duration(seconds: 60),
      ));
    }
  }

  /// Requests storage permission. Returns whether permission is granted or not
  Future<bool> _requestStoragePermission() async {
    final PermissionStatus permission = await Permission.storage.status;
    if (permission != PermissionStatus.granted) {
      if (await Permission.storage.request() != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  /// Loads the current wallpaper to the preview
  void _loadWallpaper() async {
    wallpaper = await WallpaperService.getWallpaper(ConfigService.region);

    if (kDebugMode) {
      print("Got wallpaper: $wallpaper");
    }

    setState(() {});
  }

  void _setWallpaper() async {
    if (wallpaper == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          "Wallpaper not loaded yet! Please wait...",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey.shade900,
        duration: const Duration(seconds: 3),
      ));

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 10),
            child: const SizedBox(
              height: 10,
              width: 10,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ),
          const Text(
            "Setting Wallpaper",
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade900,
      duration: const Duration(seconds: 60),
    ));

    int start = DateTime.now().millisecondsSinceEpoch;

    TextStyle linkStyle = const TextStyle(color: Colors.deepPurple);

    Object? error;

    try {
      WallpaperService.setWallpaperFromUrl(
          wallpaper!.mobileUrl, ConfigService.wallpaperScreen);
    } catch (e) {
      error = e;
      await Util.logToFile(error.toString());
    }

    // Show the initial snack bar for at least 1s
    int diff = DateTime.now().millisecondsSinceEpoch - start;
    if (diff < 1000) {
      await Future.delayed(Duration(milliseconds: 1000 - diff));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          "Wallpaper set successfully",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey.shade900,
        duration: const Duration(seconds: 3),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: RichText(
            text: TextSpan(children: [
          const TextSpan(text: "An error occurred. See the "),
          TextSpan(
              text: "log.txt",
              style: linkStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  String path = (await ConfigService.publicDirectory).path;
                  print(path);
                  var r = await OpenFile.open("$path/log.txt");
                  print("${r.type} ${r.message}");
                }),
          const TextSpan(text: " file for detailed log.")
        ])),
        backgroundColor: Colors.grey.shade900,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  /// Opens the info view of the current wallpaper
  void _openWallpaperInformationDialog() {
    if (wallpaper == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          "Wallpaper not loaded yet! Please wait...",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey.shade900,
        duration: const Duration(seconds: 3),
      ));
    }

    showDialog(
      context: context,
      builder: (context) => WallpaperInfoView(wallpaper: wallpaper!),
    );
  }

  Route _createSettingsViewRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const SettingsView(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Opens the settings window
  void _openSettingsView() {
    Navigator.pop(context);
    Navigator.push(
      context,
      _createSettingsViewRoute(),
    );
  }

  void _openAboutView(){
    Navigator.pop(context);
    showDialog(
        context: context,
        builder: (context)=>const AboutView(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(wallpaper?.title ?? ""),
        backgroundColor: Colors.black12,
      ),
      body: MainPageBody(
        wallpaper: wallpaper,
      ),
      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        animatedIconTheme: const IconThemeData(size: 30),
        // this is ignored if animatedIcon is non null
        curve: Curves.bounceIn,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        tooltip: 'Options',
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        elevation: 8.0,
        children: [
          SpeedDialChild(
              label: "Set Wallpaper",
              child: const Icon(Icons.wallpaper),
              onTap: _setWallpaper)
        ],
      ),
      drawer: MainPageDrawer(
        header: wallpaper?.copyright ?? "A Bing Image",
        onInformationTap: _openWallpaperInformationDialog,
        onSettingsTap: _openSettingsView,
        onAboutTap: _openAboutView,
      ),
    );
  }
}
