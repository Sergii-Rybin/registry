cmake_minimum_required(VERSION 3.20)

project(overloaded-port LANGUAGES NONE)

add_library(overloaded INTERFACE)
target_include_directories(overloaded INTERFACE
    $<INSTALL_INTERFACE:include>
)

install(TARGETS overloaded EXPORT overloaded-config)

install(EXPORT overloaded-config
    DESTINATION share/overloaded
    NAMESPACE overloaded::
)
