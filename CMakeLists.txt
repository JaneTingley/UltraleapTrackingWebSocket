cmake_minimum_required(VERSION 3.16.3)
project("LeapWS" VERSION 0.1.0 DESCRIPTION "Transmit hand data through a WebSocket" LANGUAGES C)

# Enforce out-of-source build
if (CMAKE_BINARY_DIR STREQUAL CMAKE_SOURCE_DIR)
    message(FATAL_ERROR "Build in a separate directory.")
endif ()

# --- 1. Local libwebsockets (Non-SSL Build) ---

# REQUIREMENT: User MUST provide LWS_CUSTOM_ROOT
if(NOT DEFINED LWS_CUSTOM_ROOT)
    message(FATAL_ERROR "❌ ERROR: LWS_CUSTOM_ROOT is not defined.\n"
                        "   You must specify the path to your custom libwebsockets build directory.\n"
                        "   Example:\n"
                        "     cmake -DLWS_CUSTOM_ROOT='/absolute/path/to/libwebsockets/build' ..")
endif()

if(NOT EXISTS "${LWS_CUSTOM_ROOT}/lib")
    message(FATAL_ERROR "❌ ERROR: The path provided for LWS_CUSTOM_ROOT does not contain a 'lib' folder.\n"
                        "   Current value: ${LWS_CUSTOM_ROOT}\n"
                        "   Please check if you pointed to the source root or the build directory.")
endif()

message(STATUS "🔍 Using custom libwebsockets from: ${LWS_CUSTOM_ROOT}")

# Find the library in the 'lib' subdirectory of the specified path
find_library(LIBWEBSOCKETS_LIB
    NAMES websockets libwebsockets
    PATHS "${LWS_CUSTOM_ROOT}/lib"
    NO_DEFAULT_PATH # Do not search system paths like /usr/local/lib
)

if (NOT LIBWEBSOCKETS_LIB)
    message(FATAL_ERROR "❌ Could not find libwebsockets in '${LWS_CUSTOM_ROOT}/lib'.\n"
                        "   Ensure you built libwebsockets successfully in that location.")
endif ()

# Verify the library doesn't link to OpenSSL (safety check)
execute_process(
    COMMAND otool -L "${LIBWEBSOCKETS_LIB}"
    OUTPUT_VARIABLE LWS_OTOOL_OUTPUT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

if("${LWS_OTOOL_OUTPUT}" MATCHES "libssl|libcrypto")
    message(WARNING "⚠️  Warning: Your libwebsockets seems to be linked against OpenSSL!\n"
                    "   The deployment script might fail if OpenSSL isn't bundled.\n"
                    "   Ensure you built libwebsockets with -DLWS_WITH_SSL=OFF.")
endif()

message(STATUS "🦾 Found libwebsockets: ${LIBWEBSOCKETS_LIB}")
get_filename_component(LWS_NAME ${LIBWEBSOCKETS_LIB} NAME)

# --- 2. Find Leap SDK (macOS only) ---
set(ULTRALEAP_ROOT "/Applications/Ultraleap Hand Tracking.app/Contents/LeapSDK")
include_directories("${ULTRALEAP_ROOT}/include")
find_library(LEAPC_LIB NAMES libLeapC.dylib LeapC PATHS "${ULTRALEAP_ROOT}/lib" NO_DEFAULT_PATH)
if (NOT LEAPC_LIB)
    message(FATAL_ERROR "libLeapC.dylib not found.")
endif ()

# --- 3. Threads ---
find_package(Threads REQUIRED)

# --- 4. Build libUtils ---
add_library(libUtils OBJECT utils.c)
target_link_libraries(libUtils PUBLIC "${LEAPC_LIB}")
target_include_directories(libUtils PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

# --- 5. Build Executable ---
add_executable(Ultraleap-Tracking-WS main.c)
target_link_libraries(Ultraleap-Tracking-WS PUBLIC libUtils Threads::Threads "${LIBWEBSOCKETS_LIB}" "${LEAPC_LIB}")

# --- 6. Bundle Libraries ---
set_target_properties(Ultraleap-Tracking-WS PROPERTIES
    INSTALL_RPATH "@loader_path"
    BUILD_RPATH "@loader_path"
    SKIP_BUILD_RPATH FALSE
    BUILD_WITH_INSTALL_RPATH TRUE
)

# 6a: Bundle libLeapC
add_custom_command(TARGET Ultraleap-Tracking-WS POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy "${LEAPC_LIB}" $<TARGET_FILE_DIR:Ultraleap-Tracking-WS>
    COMMAND install_name_tool -change "@rpath/libLeapC.6.dylib" "@loader_path/libLeapC.dylib" $<TARGET_FILE:Ultraleap-Tracking-WS>
    COMMENT "Bundling libLeapC.dylib"
)

# 6b: Bundle libwebsockets
add_custom_command(TARGET Ultraleap-Tracking-WS POST_BUILD
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/bundling_helper.sh
        $<TARGET_FILE:Ultraleap-Tracking-WS>
        "${LIBWEBSOCKETS_LIB}"
    COMMENT "Bundling libwebsockets"
)