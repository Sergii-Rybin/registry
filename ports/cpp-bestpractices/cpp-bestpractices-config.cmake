include("${CMAKE_CURRENT_LIST_DIR}/cpp-bestpractices-targets.cmake")

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
