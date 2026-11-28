cmake_minimum_required(VERSION 4.4)
project(drive_info_vcpkg_wrapper LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_subdirectory("${DRIVE_INFO_SOURCE_PATH}" drive_info_build)
