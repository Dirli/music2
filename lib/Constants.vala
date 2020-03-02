/*
 * Copyright (c) 2020 Dirli <litandrej85@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

namespace Music2.Constants {
    public const string APP_NAME = "io.elementary.music2";
    public const string DB_VERSION = "1.0";
    public const string UNKNOWN = "Unknown";
    public const string NOT_AVAILABLE = "";
    public const string QUEUE = "queue";
    public const string MPRIS_NAME = "org.mpris.MediaPlayer2.Music2";
    public const string MPRIS_PATH = "/org/mpris/MediaPlayer2";
    public const string TYPE_DATA_KEY = "setup-list-column-type";

    public const int DIALOG_MIN_WIDTH = 420;
    public const int DIALOG_MIN_HEIGHT = 300;

    public const int ANIMATION_TIMEOUT = 20;
    public const uint INTERVAL = 250;
    public const int64 SEC_INV = 1;
    public const int64 MILI_INV = 1000;
    public const int64 MICRO_INV = 1000000;
    public const int64 NANO_INV = 1000000000;

    public const string[] DECIBELS = {
        "60", "170", "310", "600", "1k", "3k", "6k", "12k", "14k", "16k"
    };

    public const string[] MEDIA_CONTENT_TYPES = {
        "audio/3gpp",
        "audio/aac",
        "audio/AMR",
        "audio/AMR-WB",
        "audio/ac3",
        "audio/basic",
        "audio/flac",
        "audio/mp2",
        "audio/mpeg",
        "audio/mp4",
        "audio/ogg",
        "audio/vnd.rn-realaudio",
        "audio/vorbis",
        "audio/x-aac",
        "audio/x-aiff",
        "audio/x-ape",
        "audio/x-flac",
        "audio/x-gsm",
        "audio/x-it",
        "audio/x-m4a",
        "audio/x-matroska",
        "audio/x-mod",
        "audio/x-ms-asf",
        "audio/x-ms-wma",
        "audio/x-mp3",
        "audio/x-mpeg",
        "audio/x-musepack",
        "audio/x-opus+ogg",
        "audio/x-pn-aiff",
        "audio/x-pn-au",
        "audio/x-pn-realaudio",
        "audio/x-pn-realaudio-plugin",
        "audio/x-pn-wav",
        "audio/x-pn-windows-acm",
        "audio/x-realaudio",
        "audio/x-real-audio",
        "audio/x-sbc",
        "audio/x-speex",
        "audio/x-tta",
        "audio/x-vorbis",
        "audio/x-vorbis+ogg",
        "audio/x-wav",
        "audio/x-wavpack",
        "audio/x-xm",
        "application/ogg",
        "application/x-extension-m4a",
        "application/x-extension-mp4",
        "application/x-flac",
        "application/x-ogg",
        "audio/x-s3m"
    };
}
