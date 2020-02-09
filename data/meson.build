conf_data = configuration_data()
conf_data.set('EXEC_PATH', join_paths (get_option('prefix'), get_option('bindir'), meson.project_name() + 'd'))

configure_file(
    input: meson.project_name() + '.service.in',
    output: '@BASENAME@',
    configuration: conf_data,
    install_dir: dep_dbus.get_pkgconfig_variable('session_bus_services_dir')
)

install_data (
    meson.project_name() + 'd',
    install_dir: join_paths(get_option('datadir'), 'applications')
)

install_data(
    meson.project_name() + '.gschema.xml',
    install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
)
