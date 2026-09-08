cmake_minimum_required(VERSION 3.16)
project(RestartApp)

find_package(Qt6 REQUIRED COMPONENTS Widgets)

qt_standard_project_setup()

add_executable(RestartApp reset.cpp)

target_link_libraries(RestartApp Qt6::Widgets)
