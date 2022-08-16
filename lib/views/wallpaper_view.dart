import 'package:bing_wallpaper_setter/services/wallpaper_service.dart';
import 'package:bing_wallpaper_setter/theme.dart' as theme;
import 'package:bing_wallpaper_setter/views/wallpaper_info_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:share_plus/share_plus.dart';

import '../services/config_service.dart';
import '../util/util.dart';

typedef AsyncBoolCallback = Future<bool> Function();

class WallpaperView extends StatefulWidget {
  final WallpaperInfo? wallpaper;
  final Widget? drawer;
  final AsyncBoolCallback? onUpdateWallpaper;
  final String? heroTag;

  const WallpaperView(
      {Key? key,
      required this.wallpaper,
      this.drawer,
      this.onUpdateWallpaper,
      this.heroTag,
      })
      : super(key: key);

  @override
  State<WallpaperView> createState() => _WallpaperViewState();
}

class _WallpaperViewState extends State<WallpaperView> {
  WallpaperInfo? get wallpaper => widget.wallpaper;

  /// Sets the current wallpaper
  void _setWallpaper() async {
    if (wallpaper == null) {
      Util.showSnackBar(
        context,
        content: const Text(
          "Wallpaper not loaded yet! Please wait...",
          style: TextStyle(color: Colors.white),
        ),
      );

      return;
    }

    Util.showSnackBar(
      context,
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
    );

    int start = DateTime.now().millisecondsSinceEpoch;

    Object? error;

    try {
      WallpaperService.setWallpaper(wallpaper!, ConfigService.wallpaperScreen);
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

    Util.hideSnackBar(context);

    if (error == null) {
      Util.showSnackBar(
        context,
        content: const Text(
          "Wallpaper set successfully",
          style: TextStyle(color: Colors.white),
        ),
      );
    } else {
      Util.showSnackBar(
        context,
        content: RichText(
          text: TextSpan(
            children: [
              const TextSpan(text: "An error occurred. See the "),
              TextSpan(
                  text: "log.txt",
                  style: theme.snackBarLinkStyle,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () async {
                      await Util.openLogFile();
                    }),
              const TextSpan(text: " file for detailed log.")
            ],
          ),
        ),
      );
    }
  }

  /// Downloads wallpaper and opens a share dialog
  void _shareWallpaper() async {
    if (wallpaper == null) {
      Util.showSnackBar(context,
          content: const Text("Wallpaper not loaded yet."));
      return;
    }
    await WallpaperService.ensureDownloaded(wallpaper!);
    Share.shareFiles([(await wallpaper!.file).path], subject: wallpaper!.title);
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

  /// Builds a spinner, indicating that the wallpaper is loading
  Widget _buildSpinner() {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// Builds the wallpaper preview
  Widget _buildWallpaper() {
    final size = MediaQuery.of(context).size;

    Widget child = CachedNetworkImage(
      imageUrl: widget.wallpaper!.mobileUrl,
      width: size.width,
      height: size.height,
      fit: BoxFit.cover,
      progressIndicatorBuilder: (context, url, downloadProgress) => Center(
        child: CircularProgressIndicator(value: downloadProgress.progress),
      ),
    );
    if(widget.heroTag != null){
      child = Hero(
        tag: widget.heroTag!,
        child: child,
      );
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Tooltip(
          message: wallpaper?.title ?? "",
          child: Text(wallpaper?.title ?? ""),
        ),
        backgroundColor: Colors.black38,
        actions: [
          IconButton(
              onPressed: _openWallpaperInformationDialog,
              icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        displacement: 80,
        onRefresh: () async {
          if (widget.onUpdateWallpaper == null) {
            return Future.value();
          }
          bool updated = await widget.onUpdateWallpaper!();

          if (!mounted) return;

          if (updated) {
            Util.showSnackBar(
              context,
              content: const Text("Wallpaper updated."),
            );
          } else {
            Util.showSnackBar(
              context,
              content: const Text("No new wallpaper."),
            );
          }
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            wallpaper == null ? _buildSpinner() : _buildWallpaper(),
          ],
        ),
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
            onTap: _setWallpaper,
          ),
          SpeedDialChild(
            label: "Share",
            child: const Icon(Icons.share),
            onTap: _shareWallpaper,
          ),
        ],
      ),
      drawer: widget.drawer,
    );
  }
}
