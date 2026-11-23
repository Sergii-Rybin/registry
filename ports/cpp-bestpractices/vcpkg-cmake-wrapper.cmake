_find_package(${ARGS})

if(DEFINED ENV{CI})
    return()
endif()

block()
    cmake_path(SET skills_dir NORMALIZE "${CMAKE_CURRENT_LIST_DIR}/../agent-skills")
    if(NOT EXISTS "${skills_dir}")
        return()
    endif()

    cmake_path(RELATIVE_PATH skills_dir BASE_DIRECTORY "${CMAKE_SOURCE_DIR}")
    file(CONFIGURE
        OUTPUT "${CMAKE_SOURCE_DIR}/.agents/skills.json"
        CONTENT "{\n  \"entries\": [\n    { \"path\": \"${skills_dir}\" }\n  ]\n}\n"
    )
endblock()
