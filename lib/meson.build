common_files = files (
    'Enums.vala',
    'Constants.vala',
    'CObjects/EqualizerPreset.vala',
    'CObjects/Media.vala',
    'Interfaces/GSTagger.vala',
    'Tools/FileUtils.vala',
    'Tools/String.vala',
    'Tools/TimeUtils.vala',
)

core_files = common_files
core_files += files (
    'Structs.vala',
    'CObjects/Scanner.vala',
)
if get_option ('sqlite')
    core_files += files (
        'DataBaseManager.vala',
    )
endif

client_files = common_files
client_files += files (
    'Interfaces/Client.vala',
)


if get_option ('gtk')
    app_files = client_files
    app_files += files (
        'Structs.vala',
        'Interfaces/GenericList.vala',
        'Interfaces/StackWrapper.vala',
        'LViews/GridView.vala',
        'LViews/ListView.vala',
        'LViews/PresetList.vala',
        'LViews/TileRenderer.vala',
        'Tools/CellDataHelper.vala',
        'Tools/GuiUtils.vala',
    )

    if get_option ('sqlite')
        app_files += files (
            'DataBaseManager.vala',
        )
    endif
endif
