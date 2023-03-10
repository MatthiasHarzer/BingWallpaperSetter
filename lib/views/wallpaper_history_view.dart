import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:bing_wallpaper_setter/views/wallpaper_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/wallpaper_info.dart';
import '../services/wallpaper_service.dart';

class WallpaperHistoryView extends StatefulWidget {
  const WallpaperHistoryView({Key? key}) : super(key: key);

  @override
  State<WallpaperHistoryView> createState() => _WallpaperHistoryViewState();
}

class _WallpaperHistoryViewState extends State<WallpaperHistoryView> {
  List<WallpaperInfo> wallpapers = [];

  @override
  void initState() {
    super.initState();

    _loadWallpapers();
  }

  Future<void> _loadWallpapers() async {
    wallpapers = await WallpaperService.getWallpaperHistory();
    setState(() {});
  }

  void _openWallpaperDetailView(WallpaperInfo wallpaper, String heroTag) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (BuildContext context) => WallpaperView(
              wallpaper: wallpaper,
              heroTag: heroTag,
            )));
  }

  Widget _buildWallpaperItem(WallpaperInfo wallpaper) {
    final double width = MediaQuery.of(context).size.width;
    final double height = width / ConfigService.wallpaperResolutionAsDouble;
    return GestureDetector(
      onTap: () =>
          _openWallpaperDetailView(wallpaper, wallpaper.day.toString()),
      child: Hero(
        tag: "hero-image-${wallpaper.day}",
        child: CachedNetworkImage(
          imageUrl: wallpaper.mobileUrl,
          width: width,
          height: height,
          progressIndicatorBuilder: (context, url, progress) => Center(
            child: SizedBox.square(
              dimension: 60,
              child: CircularProgressIndicator(
                value: progress.progress,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Wallpaper History"),
        backgroundColor: Colors.black38,
      ),
      body: SingleChildScrollView(
        child: Wrap(
          children: [
            SizedBox(
              height: 80,
              child: Container(),
            ),
            ...wallpapers
                .map((wallpaper) => _buildWallpaperItem(wallpaper))
                .toList()
          ],
        ),
      ),
    );
  }
}
