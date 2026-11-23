# Header-only port: skip redundant debug build configuration since no binaries are compiled
set(VCPKG_BUILD_TYPE release)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO sergii-rybin/overloaded
    REF 1d6f1e6d7c9bc5a4974ccfad20619af0a881560e
    SHA512 b81de7e67f2add992cb7a59deae7bdbcef23f4f1b5701f28457b8d79fbe65489d4c88e450032b4c0d707a3ad888de7be7b8707f836480fa6c918124332002362
    HEAD_REF master
)

file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

vcpkg_cmake_configure(SOURCE_PATH "${CMAKE_CURRENT_LIST_DIR}")
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME overloaded)

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
