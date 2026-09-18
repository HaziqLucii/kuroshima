cmake_minimum_required(VERSION 3.20)
project(dynamic-island LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Network Qml Quick)
find_package(LayerShellQt REQUIRED)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(dynamic-island
    main.cpp
    NiriEventStream.cpp
    NiriEventStream.h
)

qt_add_qml_module(dynamic-island
    URI DynamicIsland
    VERSION 1.0
    QML_FILES
        qml/Island.qml
)

target_link_libraries(dynamic-island PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    Qt6::Qml
    Qt6::Quick
    LayerShellQt::Interface
)
