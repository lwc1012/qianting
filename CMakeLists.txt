cmake_minimum_required(VERSION 3.16)

project(proj1 VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network Quick3D QuickControls2 SerialPort TextToSpeech Multimedia)


qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appproj1
    main.cpp
    app_logo.rc
)

qt_add_qml_module(appproj1
    URI proj1
    QML_FILES
        Main.qml
        Jiushengting.qml
        SOURCES
    RESOURCES
        meshes/lr7_mesh.mesh
        meshes/water_plane.mesh
        maps/submarine_side_view.png
        maps/submarine_academy.png
        maps/sdu_logo.svg
        maps/seats.png

        textures/001_1_diff.png
        textures/001_ddn.png
        textures/001_spec.png
        textures/002_ddn.png
        textures/002_diff.png
        textures/002_spec.png
        textures/003_1diff.png
        textures/003_ddn.png
        textures/003_spec.png
        textures/004_ddn.png
        textures/004_diff.png
        textures/004_spec.png
        textures/logo.png
        textures/mesh_1diff.png
        textures/mesh_ddn.png
        textures/mesh_spec.png
        textures/shengna_1diff.png
        textures/shengna_ddn.png
        textures/shengna_spec.png

        SOURCES serialreader.h serialreader.cpp
        SOURCES voicecontroller.h voicecontroller.cpp
        RESOURCES water.vert
        RESOURCES water.frag
)

set_target_properties(appproj1 PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appproj1
    PRIVATE Qt6::Quick Qt6::Network Qt6::Quick3D Qt6::QuickControls2 Qt6::SerialPort Qt6::TextToSpeech Qt6::Multimedia
)

include(GNUInstallDirs)
install(TARGETS appproj1
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
