import 'package:bing_wallpaper_setter/services/wallpaper_service.dart';
import 'package:flutter/material.dart';

import '../util/util.dart';

/// The wallpaper info view. Shows title, copyright, etc
class WallpaperInfoView extends StatelessWidget {
  final WallpaperInfo wallpaper;
  final TextStyle buttonStyle = const TextStyle(color: Colors.deepPurpleAccent);

  const WallpaperInfoView({Key? key, required this.wallpaper})
      : super(key: key);



  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(
        wallpaper.title,
        textAlign: TextAlign.center,
      ),
      content: Wrap(
        children: [
          Text(wallpaper.copyright),
          const Divider(),
          Text(Util.formatDay(wallpaper.day, format: 'd. MMM yyyy'), style: TextStyle(color: Colors.grey[500]),),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MaterialButton(
                onPressed: () {
                  Util.openUrl(wallpaper.copyrightLink);
                },
                child: Container(
                  child: Row(
                    children: [
                      Text(
                        "Copyright",
                        style: buttonStyle,
                      ),
                      Container(
                          margin: const EdgeInsets.only(left: 5),
                          child: Icon(
                            Icons.open_in_new,
                            size: 15,
                            color: buttonStyle.color,
                          ))
                    ],
                  ),
                ),
              ),
              MaterialButton(
                onPressed: () {
                  Util.openUrl(wallpaper.fullSizeUrl);
                },
                child: Container(
                  child: Row(
                    children: [
                      Text(
                        "Full Size",
                        style: buttonStyle,
                      ),
                      Container(
                          margin: const EdgeInsets.only(left: 5),
                          child: Icon(
                            Icons.open_in_new,
                            size: 15,
                            color: buttonStyle.color,
                          ))
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        MaterialButton(
            onPressed: () => Navigator.pop(context),
            child: Container(
                child: Text(
              "Close",
              style: buttonStyle,
            )))
      ],
    );
  }
}
