import 'package:bing_wallpaper_setter/views/wallpaper_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/wallpaper_service.dart';

class OldWallpapersView extends StatefulWidget {
  const OldWallpapersView({Key? key}) : super(key: key);

  @override
  State<OldWallpapersView> createState() => _OldWallpapersViewState();
}

class _OldWallpapersViewState extends State<OldWallpapersView> {
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
    Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) =>WallpaperView(
      wallpaper: wallpaper,
      heroTag: heroTag,
    )));

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
            SizedBox(height: 80, child: Container(),),
            ...wallpapers.map((wallpaper) {
            final double width = MediaQuery.of(context).size.width;
            return GestureDetector(
              onTap: ()=>_openWallpaperDetailView(wallpaper, wallpaper.day.toString()),
              child: Hero(
                tag: "hero-image-${wallpaper.day}",
                child: CachedNetworkImage(
                  imageUrl: wallpaper.mobileUrl,
                  width: width,
                ),
              ),
            );
          }).toList()],
        ),
      ),
    );
  }
}
