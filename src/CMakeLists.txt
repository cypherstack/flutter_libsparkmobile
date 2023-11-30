# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(flutter_libsparkmobile_library VERSION 0.0.1)

SET(CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake;${CMAKE_MODULE_PATH}")



add_library(flutter_libsparkmobile SHARED
  "flutter_libsparkmobile.cpp"
        "utils.cpp"
)

add_subdirectory(deps/boost-cmake)
add_subdirectory("deps/sparkmobile")

set_target_properties(flutter_libsparkmobile PROPERTIES
  PUBLIC_HEADER flutter_libsparkmobile.h
  OUTPUT_NAME "flutter_libsparkmobile"
)

target_link_libraries(flutter_libsparkmobile sparkmobile)

target_compile_definitions(flutter_libsparkmobile PUBLIC DART_SHARED_LIB)
