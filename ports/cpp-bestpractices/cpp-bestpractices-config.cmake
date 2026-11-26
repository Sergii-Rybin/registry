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

function(_cpp_bestpractices_collect_targets dir out_var)
    set(collected "")
    get_property(dir_targets DIRECTORY "${dir}" PROPERTY BUILDSYSTEM_TARGETS)
    foreach(tgt IN LISTS dir_targets)
        if(tgt MATCHES "^(__|@)")
            continue()
        endif()
        get_target_property(tgt_type "${tgt}" TYPE)
        if(NOT tgt_type STREQUAL "UTILITY")
            list(APPEND collected "${tgt}")
        endif()
    endforeach()

    get_property(subdirs DIRECTORY "${dir}" PROPERTY SUBDIRECTORIES)
    foreach(sub IN LISTS subdirs)
        _cpp_bestpractices_collect_targets("${sub}" sub_targets)
        list(APPEND collected ${sub_targets})
    endforeach()

    set("${out_var}" "${collected}" PARENT_SCOPE)
endfunction()

function(cpp_bestpractices_add_format_targets)
    find_program(CLANG_FORMAT_BIN clang-format)
    if(NOT CLANG_FORMAT_BIN)
        return()
    endif()

    if(ARGC GREATER 0)
        set(targets ${ARGN})
    else()
        _cpp_bestpractices_collect_targets("${CMAKE_CURRENT_SOURCE_DIR}" targets)
    endif()

    set(cpp_ext_regex "\\.(c|cc|cpp|cxx|c\\+\\+|cppm|ixx|mpp|h|hh|hpp|hxx|h\\+\\+|ipp|tpp|inl)$")
    set(format_sources "")
    foreach(tgt IN LISTS targets)
        if(TARGET "${tgt}")
            get_target_property(tgt_dir "${tgt}" SOURCE_DIR)
            set(source_props SOURCES)
            get_target_property(header_sets "${tgt}" HEADER_SETS)
            if(header_sets)
                foreach(set_name IN LISTS header_sets)
                    if(set_name STREQUAL "HEADERS")
                        list(APPEND source_props HEADER_SET)
                    else()
                        list(APPEND source_props "HEADER_SET_${set_name}")
                    endif()
                endforeach()
            endif()
            get_target_property(module_sets "${tgt}" CXX_MODULE_SETS)
            if(module_sets)
                foreach(set_name IN LISTS module_sets)
                    if(set_name STREQUAL "CXX_MODULES")
                        list(APPEND source_props CXX_MODULE_SET)
                    else()
                        list(APPEND source_props "CXX_MODULE_SET_${set_name}")
                    endif()
                endforeach()
            endif()

            foreach(prop IN LISTS source_props)
                get_target_property(files "${tgt}" "${prop}")
                if(files)
                    foreach(file IN LISTS files)
                        if(file MATCHES "^\\$<TARGET_OBJECTS:")
                            continue()
                        elseif(file MATCHES "\\$<")
                            list(APPEND format_sources
                                "$<IF:$<BOOL:${file}>,$<PATH:ABSOLUTE_PATH,NORMALIZE,${file},${tgt_dir}>,>")
                        else()
                            string(TOLOWER "${file}" file_lower)
                            if(NOT file_lower MATCHES "${cpp_ext_regex}")
                                continue()
                            endif()
                            cmake_path(ABSOLUTE_PATH file BASE_DIRECTORY "${tgt_dir}" NORMALIZE)
                            cmake_path(IS_PREFIX CMAKE_SOURCE_DIR "${file}" NORMALIZE in_source_tree)
                            cmake_path(IS_PREFIX CMAKE_BINARY_DIR "${file}" NORMALIZE in_binary_tree)
                            if(in_source_tree AND NOT in_binary_tree)
                                list(APPEND format_sources "${file}")
                            endif()
                        endif()
                    endforeach()
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
        COMMAND_EXPAND_LISTS
    )

    add_custom_target(format-check
        COMMAND "${CLANG_FORMAT_BIN}" --dry-run --Werror ${format_sources}
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        COMMENT "Checking C++ code formatting with clang-format..."
        VERBATIM
        COMMAND_EXPAND_LISTS
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
