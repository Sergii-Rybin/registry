include("${CMAKE_CURRENT_LIST_DIR}/cpp-bestpractices-targets.cmake")

function(cpp_bestpractices_enable_ccache)
    if(NOT CMAKE_GENERATOR MATCHES "Ninja|Makefiles")
        message(STATUS "ccache skipped: unsupported generator (${CMAKE_GENERATOR})")
        return()
    endif()

    find_program(CCACHE_PROGRAM ccache)
    if(NOT CCACHE_PROGRAM)
        message(WARNING "ccache not found; proceeding with default compiler.")
        return()
    endif()

    set(CMAKE_C_COMPILER_LAUNCHER "${CCACHE_PROGRAM}" PARENT_SCOPE)
    set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}" PARENT_SCOPE)

    # MSVC defaults to /Zi (shared .pdb via mspdbsrv.exe), which bypasses ccache.
    # Switch to Embedded (/Z7) so debug info is stored inside .obj files.
    if(MSVC)
        set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "$<$<CONFIG:Debug,RelWithDebInfo>:Embedded>" PARENT_SCOPE)
    endif()

    message(STATUS "ccache enabled: ${CCACHE_PROGRAM}")
endfunction()

function(cpp_bestpractices_add_format_targets)
    find_program(CLANG_FORMAT_BIN clang-format)
    if(NOT CLANG_FORMAT_BIN)
        return()
    endif()

    set(format_sources "")
    foreach(tgt IN LISTS ARGN)
        if(TARGET "${tgt}")
            foreach(prop IN ITEMS SOURCES HEADER_SET CXX_MODULE_SET)
                get_target_property(files "${tgt}" "${prop}")
                if(files)
                    list(APPEND format_sources ${files})
                endif()
            endforeach()
        endif()
    endforeach()

    if(NOT format_sources)
        return()
    endif()

    list(REMOVE_DUPLICATES format_sources)

    add_custom_target(format
        COMMAND "${CLANG_FORMAT_BIN}" -i ${format_sources}
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        COMMENT "Auto-formatting C++ source files with clang-format..."
        VERBATIM
    )

    add_custom_target(format-check
        COMMAND "${CLANG_FORMAT_BIN}" --dry-run --Werror ${format_sources}
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        COMMENT "Checking C++ code formatting with clang-format..."
        VERBATIM
    )
endfunction()

function(cpp_bestpractices_add_docs_targets)
    cmake_parse_arguments(ARG "" "TIMEOUT" "FILES;TARGETS" ${ARGN})

    if(NOT ARG_FILES)
        message(FATAL_ERROR "cpp_bestpractices_add_docs_targets: FILES is required")
    endif()

    set(exec_timeout 15)
    if(ARG_TIMEOUT)
        set(exec_timeout "${ARG_TIMEOUT}")
    endif()

    set(target_map "")
    foreach(tgt IN LISTS ARG_TARGETS)
        list(APPEND target_map "${tgt}=$<TARGET_FILE:${tgt}>")
    endforeach()

    foreach(mode IN ITEMS sync check)
        set(check_only "$<STREQUAL:${mode},check>")
        add_custom_target("docs-${mode}"
            COMMAND "${CMAKE_COMMAND}"
                -D "SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
                -D "FILES=${ARG_FILES}"
                -D "TARGET_MAP=${target_map}"
                -D "EMULATOR=${CMAKE_CROSSCOMPILING_EMULATOR}"
                -D "EXEC_TIMEOUT=${exec_timeout}"
                -D "CHECK_ONLY=${check_only}"
                -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/sync-docs.cmake"
            DEPENDS ${ARG_TARGETS}
            COMMENT "Docs (${mode}): syncing code snippets and executable outputs..."
            VERBATIM
        )
    endforeach()
endfunction()
