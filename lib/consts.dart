// ignore_for_file: constant_identifier_names

const BASE_URL = "https://www.bing.com/HPImageArchive.aspx?format=js&mkt=";

const BG_WALLPAPER_TASK_ID = "bg_wallpaper_task";
const BG_TASK_RECURRING_TIME = 1; //h
const BG_TASK_RECURRING_TIMEOUT = 1.5; //h

final WALLPAPER_REGEX = RegExp("wallpaper_\d{4}\.jpg", caseSensitive: false);