project(
    'io.elementary.music2',
    'vala', 'c',
    version: '0.1.0'
)

vala_args = []

dep_gio = dependency ('gio-2.0')
dep_gst = dependency ('gstreamer-1.0')

core_deps = [
    dep_gio,
    dep_gst,
]

subdir('core')
