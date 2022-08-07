import 'package:bing_wallpaper_setter/services/wallpaper_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MainPageBody extends StatefulWidget {
  final WallpaperInfo? wallpaper;

  const MainPageBody({Key? key, required this.wallpaper}) : super(key: key);

  @override
  State<MainPageBody> createState() => _MainPageBodyState();
}

class _MainPageBodyState extends State<MainPageBody> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildSpinner() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildWallpaper() {
    final size = MediaQuery.of(context).size;
    return CachedNetworkImage(
      imageUrl: widget.wallpaper!.mobileUrl,
      width: size.width,
      height: size.height,
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.wallpaper == null ? _buildSpinner() : _buildWallpaper();
  }
}
