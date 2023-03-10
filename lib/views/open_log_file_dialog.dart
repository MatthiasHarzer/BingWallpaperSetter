import 'package:bing_wallpaper_setter/util/log.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/config_service.dart';

class OpenLogFileDialog extends StatelessWidget {
  const OpenLogFileDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        "Log File",
        textAlign: TextAlign.center,
      ),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton(
            onPressed: openLogFile,
            child: Row(
              children: const [
                Icon(Icons.open_in_new),
                SizedBox(width: 10),
                Text("OPEN"),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await Share.shareFiles([ConfigService.logFile.path]);
            },
            child: Row(
              children: const [
                Icon(Icons.share),
                SizedBox(width: 10),
                Text("SHARE"),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("OK"),
        ),
      ],
    );
  }
}
