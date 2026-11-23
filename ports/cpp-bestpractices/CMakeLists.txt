cmake_minimum_required(VERSION 3.20)

project(cpp-bestpractices-port LANGUAGES NONE)

# Create the interface target
add_library(cpp-bestpractices INTERFACE)

# Attach strict compiler warning flags
target_compile_options(cpp-bestpractices INTERFACE
    $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall;-Wextra;-Wpedantic;-Wconversion;-Wsign-conversion>
    $<$<CXX_COMPILER_ID:MSVC>:/W4;/permissive->
)

# Define installation and export rules
install(TARGETS cpp-bestpractices EXPORT cpp-bestpractices-config)

install(EXPORT cpp-bestpractices-config
    DESTINATION share/cpp-bestpractices
    NAMESPACE cpp-bestpractices::
)
