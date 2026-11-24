set(VCPKG_BUILD_TYPE release)
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

set(SOURCE_PATH "${CMAKE_CURRENT_LIST_DIR}")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")

vcpkg_cmake_install()

vcpkg_cmake_config_fixup(PACKAGE_NAME docs-render)

vcpkg_copy_tools(TOOL_NAMES docs-render AUTO_CLEAN)

file(INSTALL
    "${SOURCE_PATH}/usage"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")

if("skills" IN_LIST FEATURES)
    file(INSTALL
        "${SOURCE_PATH}/skill/"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/agent-skills/${PORT}"
    )
endif()
