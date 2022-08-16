import 'package:flutter/material.dart';
import 'package:http/http.dart';

class MainPageDrawer extends StatelessWidget {
  final String header;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onAboutTap;
  final VoidCallback? onOldWallpapersTab;

  MainPageDrawer(
      {Key? key,
      this.header = "Bing Wallpaper",
      this.onSettingsTap,
      this.onAboutTap,
      this.onOldWallpapersTab})
      : super(key: key);

  final TextStyle itemTextStyle = TextStyle(
      color: Colors.grey[200]!, fontSize: 16, fontWeight: FontWeight.w500);

  Widget _buildItem(
      {required IconData icon, required String text, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        // mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            icon,
            color: itemTextStyle.color,
            size: (itemTextStyle.fontSize! * 1.5),
          ),
          Container(
            margin: const EdgeInsets.only(left: 30),
            child: Text(
              text,
              style: itemTextStyle,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(canvasColor: Colors.grey[900]),
      child: Drawer(
        child: ListView(
          primary: true,
          padding: EdgeInsets.zero,
          children: [
            SizedBox(
              height: 280,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.all(15),
                  child: Text(
                    header,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
            ),
            const Divider(),
            _buildItem(
              icon: Icons.history,
              text: "Wallpaper History",
              onTap: onOldWallpapersTab,
            ),
            _buildItem(
              icon: Icons.settings,
              text: "Settings",
              onTap: onSettingsTap,
            ),
            _buildItem(
              icon: Icons.help_outlined,
              text: "About",
              onTap: onAboutTap,
            ),
          ],
        ),
      ),
    );
  }
}
