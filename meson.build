project(
    'io.elementary.music2',
    'vala', 'c',
    version: '0.1.0'
)

add_global_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    language:'c'
)

vala_args = []

dep_glib = dependency('glib-2.0')
dep_gio = dependency ('gio-2.0')
dep_gst = dependency ('gstreamer-1.0')
dep_pbutils = dependency ('gstreamer-pbutils-1.0')
dep_gee = dependency ('gee-0.8')
dep_dbus = dependency ('dbus-1')

if get_option ('sqlite')
    dep_sqlite = dependency ('sqlite3')
endif

core_deps = [
    dep_gio,
    dep_gst,
    dep_gee,
    dep_pbutils,
]

if get_option ('sqlite')
    core_deps += dep_sqlite
endif

cli_deps = [
    dep_glib,
    dep_gio,
    dep_gst,
    dep_pbutils,
]

subdir ('data')
subdir ('lib')
subdir ('cli')
subdir ('core')
if get_option ('gtk')
    app_deps = [
        dep_gio,
        dep_pbutils,
        dependency ('gtk+-3.0'),
        dependency ('granite'),
    ]

    if get_option ('sqlite')
        app_deps += dep_sqlite
    endif

    subdir ('src')
endif

meson.add_install_script('meson/meson_post_install.py')
