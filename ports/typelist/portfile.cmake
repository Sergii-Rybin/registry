vcpkg_from_git(
    OUT_SOURCE_PATH SOURCE_PATH
    URL https://github.com/Sergii-Rybin/typelist.git
    REF 25a6b403877a97197e281e90f4506fc210eb6d66
    HEAD_REF master
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        reflection TYPELIST_BUILD_REFLECTION
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DTYPELIST_BUILD_TESTS=OFF
        -DTYPELIST_BUILD_EXAMPLES=OFF
        -DTYPELIST_BUILD_DOCS=OFF
        -DTYPELIST_USE_BESTPRACTICES=OFF
)

vcpkg_cmake_install()

vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/typelist)

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
