cmake_minimum_required(VERSION 4.4)

if(CMAKE_VERSION VERSION_LESS 4.5)
    # vcpkg currently bundles CMake 4.4.x, which gates `import std;` behind this UUID.
    set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "f35a9ac6-8463-4d38-8eec-5d6008153e7d")
    set(CMAKE_CXX_MODULE_STD ON)
endif()

project(docs-render VERSION 1.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(nlohmann_json CONFIG REQUIRED)
find_package(inja CONFIG REQUIRED)
find_package(subprocess CONFIG REQUIRED)

add_executable(docs-render src/main.cpp)
target_link_libraries(docs-render PRIVATE
    pantor::inja
    nlohmann_json::nlohmann_json
    subprocess::subprocess
)

if(MSVC)
    target_compile_options(docs-render PRIVATE /W4 /permissive- /utf-8)
else()
    target_compile_options(docs-render PRIVATE -Wall -Wextra -Wpedantic)
endif()

install(TARGETS docs-render
    RUNTIME DESTINATION bin
)

install(FILES
    docs-render-config.cmake
    DESTINATION share/docs-render
)
