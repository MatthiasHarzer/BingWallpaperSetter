import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as web;

class AboutView extends StatelessWidget {
  const AboutView({Key? key}) : super(key: key);

  final TextStyle highlightStyle =
      const TextStyle(color: Colors.deepPurpleAccent);

  Widget _buildItem(
      {required Widget title, Widget? subtitle, VoidCallback? onTap}) {
    return ListTile(
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        "About",
        textAlign: TextAlign.center,
      ),
      content: Wrap(
        children: [
          _buildItem(
            title: const Text("A Bing wallpaper app."),
            subtitle: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.grey[400]),
                children: [
                  const TextSpan(text: "Made by "),
                  TextSpan(
                    text: "Matthias Harzer",
                    style: highlightStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        web.launchUrl(Uri.parse("https://matthiasharzer.de/"));
                      },
                  ),
                  const TextSpan(text: " with "),
                  TextSpan(
                    text: "Flutter",
                    style: highlightStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        web.launchUrl(Uri.parse("https://flutter.dev/"));
                      },
                  ),
                ],
              ),
            ),
          ),
          _buildItem(
            title: const Text("Version"),
            subtitle: Text(ConfigService.packageInfo.version),
          ),
          _buildItem(
            title: const Text("GitHub"),
                subtitle: const Text("github.com/MatthiasHarzer/BingWallpaperSetter"),
            onTap: ()=>web.launchUrl(Uri.parse("https://github.com/MatthiasHarzer/BingWallpaperSetter")),
          )
        ],
      ),
    );
  }
}
