cmake_minimum_required(VERSION 3.20)

project(cpp-bestpractices-port LANGUAGES NONE)

# Warning Levels: lite -> cpp-bestpractices (default) -> paranoid

# 1. Lite: baseline warnings and cross-platform compiler hygiene
add_library(lite INTERFACE)
target_compile_options(lite INTERFACE
    $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:
        -Wall                     # enable standard set of common warnings
        -Wextra                   # enable additional useful warnings
        -Wpedantic                # enforce strict ISO C++ conformance
        -fdiagnostics-color=always # keep colored diagnostics in Ninja/Docker/CI
    >
    $<$<CXX_COMPILER_ID:MSVC>:
        /W4                       # high baseline warning level
        /permissive-              # enforce strict ISO C++ conformance
        /utf-8                    # treat source and execution charsets as UTF-8
        /Zc:__cplusplus           # report accurate __cplusplus standard value
        /Zc:preprocessor          # enable standards-conforming preprocessor
        /diagnostics:caret        # show caret column indicators in diagnostics
    >
)

# 2. Default (cpp-bestpractices): recommended strict C++ Best Practices warnings
add_library(cpp-bestpractices INTERFACE)
target_link_libraries(cpp-bestpractices INTERFACE lite)
target_compile_options(cpp-bestpractices INTERFACE
    $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:
        -Wshadow                  # variable declaration shadows an outer scope one
        -Wnon-virtual-dtor        # class with virtual functions has non-virtual destructor
        -Wold-style-cast          # C-style cast used instead of C++ cast
        -Wcast-align              # pointer cast increases required alignment
        -Wunused                  # unused variables, parameters, or functions
        -Woverloaded-virtual      # function hides overloaded virtual function from base
        -Wconversion              # implicit type conversions that may alter a value
        -Wsign-conversion         # implicit conversions between signed and unsigned
        -Wnull-dereference        # potential null pointer dereference
        -Wdouble-promotion        # implicit promotion from float to double
        -Wformat=2                # strict printf/scanf format string security checks
        -Wimplicit-fallthrough    # switch case falls through without [[fallthrough]]
    >
    $<$<CXX_COMPILER_ID:GNU>:
        -Wduplicated-cond         # duplicated conditions in if-else-if chains
        -Wduplicated-branches     # identical branches in if-else statements
        -Wlogical-op              # suspicious use of logical operators in expressions
        -Wuseless-cast            # explicit cast to the same type
    >
    $<$<CXX_COMPILER_ID:MSVC>:
        /w14242 # conversion possible loss of data
        /w14254 # operator conversion possible loss of data
        /w14263 # member function does not override any base class virtual member function
        /w14265 # class has virtual functions, but destructor is not virtual
        /w14287 # unsigned/negative constant mismatch
        /we4289 # loop control variable declared in for-loop used outside scope
        /w14296 # expression is always boolean_value
        /w14311 # pointer truncation
        /w14545 # expression before comma evaluates to a function missing an argument list
        /w14546 # function call before comma missing argument list
        /w14547 # operator before comma has no effect
        /w14549 # operator before comma has no effect; did you intend another operator
        /w14555 # expression has no effect
        /w14619 # pragma warning: there is no warning number
        /w14640 # thread-unsafe static member initialization
        /w14826 # conversion is sign-extended
        /w14905 # wide string literal cast to LPSTR
        /w14906 # string literal cast to LPWSTR
        /w14928 # illegal copy-initialization
    >
)

# 3. Paranoid: extra-strict checks for critical core modules
add_library(paranoid INTERFACE)
target_link_libraries(paranoid INTERFACE cpp-bestpractices)
target_compile_options(paranoid INTERFACE
    $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:
        -Wcast-qual                     # cast removes const/volatile qualifier
        -Wundef                         # undefined identifier evaluated in #if directive
        -Wswitch-enum                   # switch on enum missing explicit enumerator case
        -Wfloat-equal                   # direct equality comparison of floating-point values
        -Wzero-as-null-pointer-constant # literal 0 used instead of nullptr
        -Wmissing-declarations          # global function defined without prior declaration
        -Wredundant-decls               # entity declared more than once in the same scope
    >
    $<$<CXX_COMPILER_ID:MSVC>:
        /w14266 # no override available for virtual member function from base
        /w14365 # signed/unsigned mismatch
        /w14388 # signed/unsigned mismatch
        /w14582 # constructor is not implicitly called
        /w14583 # destructor is not implicitly called
        /w14623 # default constructor implicitly defined as deleted
        /w14625 # copy constructor implicitly defined as deleted
        /w14626 # assignment operator implicitly defined as deleted
        /w15026 # move constructor implicitly defined as deleted
        /w15027 # move assignment operator implicitly defined as deleted
    >
)

# Modifiers: werror, hardening, asan, tsan

# Treat warnings as errors (opt-in, ideal for CI presets)
add_library(werror INTERFACE)
target_compile_options(werror INTERFACE
    $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Werror>
    $<$<CXX_COMPILER_ID:MSVC>:/WX>
)

# Standard library hardening (bounds & precondition checks with low overhead)
add_library(hardening INTERFACE)
target_compile_definitions(hardening INTERFACE
    $<$<NOT:$<CXX_COMPILER_ID:MSVC>>:_GLIBCXX_ASSERTIONS>
    $<$<CXX_COMPILER_ID:Clang,AppleClang>:_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST>
)

# Address & Undefined Behavior Sanitizers
add_library(asan INTERFACE)
target_compile_options(asan INTERFACE
    $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-fsanitize=address,undefined;-fno-omit-frame-pointer>
    $<$<CXX_COMPILER_ID:MSVC>:/fsanitize=address>
)
target_link_options(asan INTERFACE
    $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-fsanitize=address,undefined>
)

# Thread Sanitizer
add_library(tsan INTERFACE)
target_compile_options(tsan INTERFACE
    $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-fsanitize=thread;-fno-omit-frame-pointer>
)
target_link_options(tsan INTERFACE
    $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-fsanitize=thread>
)

# Installation & Export
install(TARGETS
    lite
    cpp-bestpractices
    paranoid
    werror
    hardening
    asan
    tsan
    EXPORT cpp-bestpractices-targets
)

install(EXPORT cpp-bestpractices-targets
    DESTINATION share/cpp-bestpractices
    NAMESPACE cpp-bestpractices::
)

install(FILES
    cpp-bestpractices-config.cmake
    sync-docs.cmake
    DESTINATION share/cpp-bestpractices
)
