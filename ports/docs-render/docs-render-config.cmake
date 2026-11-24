if(NOT TARGET docs-render::docs-render)
    block()
        set(_ext "")
        if(CMAKE_HOST_WIN32)
            set(_ext ".exe")
        endif()
        cmake_path(SET _bin NORMALIZE
            "${CMAKE_CURRENT_LIST_DIR}/../../tools/docs-render/docs-render${_ext}"
        )
        add_executable(docs-render::docs-render IMPORTED)
        set_target_properties(docs-render::docs-render PROPERTIES
            IMPORTED_LOCATION "${_bin}"
        )
    endblock()
endif()

function(docs_render_add_targets)
    cmake_parse_arguments(ARG "" "TEMPLATE;OUTPUT;TIMEOUT" "IN_PLACE;DATA;TARGETS" ${ARGN})

    if(ARG_IN_PLACE AND (ARG_TEMPLATE OR ARG_OUTPUT))
        message(FATAL_ERROR "docs_render_add_targets: IN_PLACE is mutually exclusive with TEMPLATE/OUTPUT")
    endif()

    if(NOT ARG_IN_PLACE)
        if(NOT ARG_TEMPLATE)
            message(FATAL_ERROR "docs_render_add_targets: either IN_PLACE or TEMPLATE+OUTPUT is required")
        endif()
        if(NOT ARG_OUTPUT)
            message(FATAL_ERROR "docs_render_add_targets: OUTPUT is required when TEMPLATE is specified")
        endif()
    endif()

    set(_cmd_args
        --source-dir "${CMAKE_CURRENT_SOURCE_DIR}"
    )

    if(ARG_IN_PLACE)
        foreach(_file IN LISTS ARG_IN_PLACE)
            list(APPEND _cmd_args --in-place "${_file}")
        endforeach()
        string(JOIN ", " _desc ${ARG_IN_PLACE})
        set(_render_comment "Rendering in-place docs: ${_desc}...")
        set(_check_comment "Checking in-place docs: ${_desc}...")
    else()
        list(APPEND _cmd_args
            --template "${ARG_TEMPLATE}"
            --output "${ARG_OUTPUT}"
        )
        set(_render_comment "Rendering ${ARG_OUTPUT} from ${ARG_TEMPLATE}...")
        set(_check_comment "Checking ${ARG_OUTPUT} against ${ARG_TEMPLATE}...")
    endif()

    if(ARG_TIMEOUT)
        list(APPEND _cmd_args --timeout "${ARG_TIMEOUT}")
    endif()

    if(CMAKE_CROSSCOMPILING_EMULATOR)
        string(JOIN " " _emulator_cmd ${CMAKE_CROSSCOMPILING_EMULATOR})
        list(APPEND _cmd_args --emulator "${_emulator_cmd}")
    endif()

    foreach(_data_item IN LISTS ARG_DATA)
        list(APPEND _cmd_args --data "${_data_item}")
    endforeach()

    foreach(_tgt IN LISTS ARG_TARGETS)
        list(APPEND _cmd_args --target "${_tgt}=$<TARGET_FILE:${_tgt}>")
    endforeach()

    add_custom_target(docs-render
        COMMAND docs-render::docs-render ${_cmd_args}
        DEPENDS ${ARG_TARGETS}
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        COMMENT "${_render_comment}"
        VERBATIM
    )

    add_custom_target(docs-render-check
        COMMAND docs-render::docs-render ${_cmd_args} --check
        DEPENDS ${ARG_TARGETS}
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        COMMENT "${_check_comment}"
        VERBATIM
    )
endfunction()
