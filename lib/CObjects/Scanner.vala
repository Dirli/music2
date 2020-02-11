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

namespace Music2 {
    public class CObjects.Scanner : Interfaces.GSTagger {
        private int total_files;

        public Scanner () {}

        public void start_scan (string uri) {
            total_files = -1;
            total_scan = 0;
            scan_directory ("file://" + uri);
        }

        public bool stop_scan () {
            return total_files > 0 && total_scan >= total_files;
        }

        private void scan_directory (string uri) {
            new Thread<void*> ("scan_directory", () => {

                var directory = GLib.File.new_for_uri (uri.replace ("#", "%23"));
                int files_counter = 0;
                try {
                    var children = directory.enumerate_children (
                        "standard::*",
                        FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

                    GLib.FileInfo? file_info = null;
                    while ((file_info = children.next_file ()) != null) {
                        if (file_info.get_is_hidden () || file_info.get_is_symlink () || file_info.get_file_type () == FileType.DIRECTORY) {
                            continue;
                        }

                        string mime_type = file_info.get_content_type ();
                        if (Tools.FileUtils.is_audio_file (mime_type)) {
                            ++files_counter;
                            add_discover_uri (directory.get_uri () + "/" + file_info.get_name ().replace ("#", "%23").replace ("%", "%25"));
                        }
                    }

                    total_files = files_counter;

                    children.close ();
                    children.dispose ();
                } catch (Error err) {
                    warning ("%s\n%s", err.message, uri);
                }

                directory.dispose ();
                return null;
            });
        }

        protected override CObjects.Media? create_media (Gst.PbUtils.DiscovererInfo info) {
            var tags = info.get_tags ();
            CObjects.Media? track = null;

            if (tags != null) {
                string o;

                var t_uri = info.get_uri ();
                track = new CObjects.Media (t_uri);
                track.tid = t_uri.hash ();

                if (tags.get_string (Gst.Tags.TITLE, out o)) {
                    track.title = o;
                }
                if (track.title.strip () == "") {
                    track.title = GLib.Path.get_basename (info.get_uri ());
                }

                if (tags.get_string (Gst.Tags.ALBUM, out o)) {
                    track.album = o;
                }

                if (tags.get_string (Gst.Tags.ALBUM_ARTIST, out o)) {
                    track.artist = o;
                } else if (tags.get_string (Gst.Tags.ARTIST, out o)) {
                    track.artist = o;
                }

                string genre;
                if (tags.get_string (Gst.Tags.GENRE, out genre)) {
                    track.genre = genre;
                }

                uint track_number;
                if (tags.get_uint (Gst.Tags.TRACK_NUMBER, out track_number)) {
                    track.track = track_number;
                }

                uint bitrate;
                if (tags.get_uint (Gst.Tags.BITRATE, out bitrate)) {
                    track.bitrate = bitrate / 1000;
                }

                Gst.DateTime? datetime;
                if (tags.get_date_time (Gst.Tags.DATE_TIME, out datetime)) {
                    if (datetime != null) {
                        track.year = datetime.get_year ();
                    } else {
                        Date? date;
                        if (tags.get_date (Gst.Tags.DATE, out date)) {
                            if (date != null) {
                                track.year = date.get_year ();
                            }
                        }
                    }
                }

                uint64 duration = info.get_duration ();
                if (duration == 0) {
                    if (!tags.get_uint64 (Gst.Tags.DURATION, out duration)) {
                        duration = 0;
                    }
                }

                track.length = (uint) Tools.TimeUtils.nano_to_mili ((int64) duration);
            }

            return track;
        }
    }
}
