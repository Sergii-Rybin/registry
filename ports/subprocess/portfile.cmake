vcpkg_from_git(
    OUT_SOURCE_PATH SOURCE_PATH
    URL https://github.com/Sergii-Rybin/subprocess.git
    REF 7d24e9069b4c9252dd9254b76da94ebf9016fc2a
    HEAD_REF master
)

# CMake 4.4.5 (bundled by vcpkg) expects UUID f35a9ac6-8463-4d38-8eec-5d6008153e7d for `import std;`
vcpkg_replace_string(
    "${SOURCE_PATH}/CMakeLists.txt"
    "451f2fe2-a8a2-47c3-bc32-94786d8fc91b"
    "f35a9ac6-8463-4d38-8eec-5d6008153e7d"
    IGNORE_UNCHANGED
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        modules SUBPROCESS_BUILD_MODULES
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DSUBPROCESS_BUILD_TESTS=OFF
        -DSUBPROCESS_BUILD_EXAMPLES=OFF
        -DSUBPROCESS_BUILD_DOCS=OFF
        -DSUBPROCESS_USE_BESTPRACTICES=OFF
)

vcpkg_cmake_install()

vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/subprocess)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

file(INSTALL
    "${CMAKE_CURRENT_LIST_DIR}/usage"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

vcpkg_install_copyright(FILE_LIST "${CMAKE_CURRENT_LIST_DIR}/LICENSE")

if("skills" IN_LIST FEATURES)
    file(INSTALL
        "${CMAKE_CURRENT_LIST_DIR}/skill/"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/agent-skills/${PORT}"
    )
endif()
