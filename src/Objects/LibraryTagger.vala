namespace Music2 {
    public class Objects.LibraryTagger : Interfaces.GSTagger {
        private Gee.HashSet<string> covers_exist;
        public int scaned_files {
            get {
                return total_scan;
            }
        }

        public LibraryTagger () {
            covers_exist = new Gee.HashSet<string> ();
        }

        protected override CObjects.Media? create_media (Gst.PbUtils.DiscovererInfo info) {
            var tags = info.get_tags ();
            CObjects.Media? track = null;
            if (tags != null) {
                string o;

                var t_uri = info.get_uri ();
                track = new CObjects.Media (t_uri);

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

                string cov_name = track.year.to_string () + track.album;
                string cov_hash = cov_name.hash ().to_string ();

                string cov_path = GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S,
                                                        GLib.Environment.get_user_cache_dir (),
                                                        Constants.APP_NAME,
                                                        cov_hash);

                if (!covers_exist.contains (cov_path)) {
                    Gdk.Pixbuf pixbuf = null;
                    var sample = get_cover_sample (tags);

                    if (sample == null) {
                        tags.get_sample_index (Gst.Tags.PREVIEW_IMAGE, 0, out sample);
                    }

                    if (sample != null) {
                        var buffer = sample.get_buffer ();

                        if (buffer != null) {
                            pixbuf = get_pixbuf_from_buffer (buffer);
                            if (pixbuf != null) {
                                var dest = Tools.FileUtils.get_cache_directory ("covers").get_child (cov_hash);
                                if (covers_exist.add (cov_path)) {
                                    try {
                                        var output_stream = dest.create (FileCreateFlags.NONE);

                                        uint8[] pix_buf;
                                        pixbuf.save_to_buffer (out pix_buf, "jpeg");

                                        output_stream.write (pix_buf);
                                        output_stream.close (null);
                                    } catch (Error e) {
                                        warning (e.message);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            return track;
        }

        private Gst.Sample? get_cover_sample (Gst.TagList tag_list) {
            Gst.Sample cover_sample = null;
            Gst.Sample sample;
            for (int i = 0; tag_list.get_sample_index (Gst.Tags.IMAGE, i, out sample); i++) {
                var caps = sample.get_caps ();
                unowned Gst.Structure caps_struct = caps.get_structure (0);
                int image_type = Gst.Tag.ImageType.UNDEFINED;
                caps_struct.get_enum ("image-type", typeof (Gst.Tag.ImageType), out image_type);
                if (image_type == Gst.Tag.ImageType.UNDEFINED && cover_sample == null) {
                    cover_sample = sample;
                } else if (image_type == Gst.Tag.ImageType.FRONT_COVER) {
                    return sample;
                }
            }
            return cover_sample;
        }

        private Gdk.Pixbuf? get_pixbuf_from_buffer (Gst.Buffer buffer) {
            Gst.MapInfo map_info;

            if (!buffer.map (out map_info, Gst.MapFlags.READ)) {
                warning ("Could not map memory buffer");
                return null;
            }

            Gdk.Pixbuf pix = null;

            try {
                var loader = new Gdk.PixbufLoader ();

                if (loader.write (map_info.data) && loader.close ()) {
                    pix = loader.get_pixbuf ();
                }

            } catch (Error err) {
                warning ("Error processing image data: %s", err.message);
            }

            buffer.unmap (map_info);

            return pix;
        }
    }
}
