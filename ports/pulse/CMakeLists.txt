cmake_minimum_required(VERSION 3.20)

project(pulse-port LANGUAGES NONE)

add_library(pulse INTERFACE)
target_include_directories(pulse INTERFACE
    $<INSTALL_INTERFACE:include>
)
target_compile_features(pulse INTERFACE cxx_std_23)

install(TARGETS pulse EXPORT pulse-config)

install(EXPORT pulse-config
    DESTINATION share/pulse
    NAMESPACE pulse::
)
