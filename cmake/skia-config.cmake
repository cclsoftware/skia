#************************************************************************************************
#
# Skia CMake Configuration
#
# Copyright (c) 2023 CCL Software Licensing GmbH. All Rights Reserved.
#
# Permission to use this file is subject to commercial licensing
# terms and conditions. For more information, please visit ccl.dev.
#
# Filename    : skia-config.cmake
# Created by  : Julian Wolff
# Description : Custom CMake target for Skia
#
#************************************************************************************************

include_guard (GLOBAL)

ccl_find_path (skia_SOURCE_DIR NAMES "BUILD.gn" HINTS "${CMAKE_CURRENT_LIST_DIR}/.." DOC "Skia directory")
ccl_find_program (NINJA NAMES "ninja" HINTS "${CCL_TOOLS_BINDIR}/${VENDOR_HOST_PLATFORM}/depot_tools" PATH_SUFFIXES "${CMAKE_HOST_SYSTEM_PROCESSOR}" DOC "Ninja executable")

find_package (Python3 REQUIRED COMPONENTS Interpreter)
find_program (SHELL sh REQUIRED)

mark_as_advanced (skia_SOURCE_DIR NINJA Python3 SHELL)

set (SKIA_IS_DEBUG "is_debug=false")
set (buildtype "release")
option (SKIA_DEBUG "Build Skia with 'is_debug=true'" OFF)
if (SKIA_DEBUG)
	set (SKIA_IS_DEBUG "is_debug=true")
	set (buildtype "debug")
endif ()

if (CMAKE_C_COMPILER_LAUNCHER)
	set (CCACHE_WRAPPER_PATH "'${CMAKE_C_COMPILER_LAUNCHER}'")
else ()
	set (CCACHE_WRAPPER_PATH "")
endif ()

set (SKIA_SHARED_ARGS "cc=\\\"${CMAKE_C_COMPILER}\\\" cxx=\\\"${CMAKE_CXX_COMPILER}\\\" cc_wrapper=\\\"${CCACHE_WRAPPER_PATH}\\\" ${SKIA_IS_DEBUG} is_official_build=false skia_use_expat=false skia_use_harfbuzz=true skia_use_libwebp_decode=false skia_use_libwebp_encode=false skia_use_libheif=false skia_use_icu=true skia_use_sfntly=false skia_use_piex=false skia_use_zlib=true skia_use_xps=false skia_enable_spirv_validation=false skia_enable_tools=false skia_enable_skottie=false skia_enable_skshaper=true skia_enable_sksl=false skia_pdf_subset_harfbuzz=true skia_use_libjpeg_turbo_encode=true skia_use_libpng_encode=true skia_use_libjpeg_turbo_decode=true skia_use_libpng_decode=true skia_use_libgifcodec=true")

set (filecontent
	"#!${SHELL}")
set (SKIA_GN "${skia_SOURCE_DIR}/bin/gn")
set (SKIA_PRE_GN "")
set (SKIA_POST_GN "")

add_custom_command (OUTPUT ${SKIA_GN}
	COMMAND ${Python3_EXECUTABLE} ${skia_SOURCE_DIR}/bin/fetch-gn
	VERBATIM USES_TERMINAL
)

if(UNIX AND NOT APPLE)
	set (skia_flavors ${VENDOR_TARGET_ARCHITECTURE})
elseif (APPLE)
	set (skia_flavors ${VENDOR_PLATFORM})
endif ()

option (SKIA_USE_SYSTEM_HARFBUZZ "Link Skia against system harfbuzz library" ON)
string (MD5 options_hash "${skia_FIND_COMPONENTS} ${SKIA_USE_SYSTEM_HARFBUZZ}")

foreach (flavor ${skia_flavors})
	set (out_dir "out/cmake_${flavor}_${buildtype}_${options_hash}")
	set (skia_outdir_${flavor} "${out_dir}")
	set (skia_output_${flavor} "${skia_SOURCE_DIR}/${out_dir}/libskia.a")
	set (skshaper_output_${flavor} "${skia_SOURCE_DIR}/${out_dir}/libskshaper.a")
	set (skunicode_output_${flavor} "${skia_SOURCE_DIR}/${out_dir}/libskunicode.a")
	set (skparagraph_output_${flavor} "${skia_SOURCE_DIR}/${out_dir}/libskparagraph.a")

	list (APPEND skia_outputs "${skia_output_${flavor}}" "${skshaper_output_${flavor}}" "${skunicode_output_${flavor}}" "${skparagraph_output_${flavor}}")
	list (APPEND skia_byproducts "${skia_SOURCE_DIR}/${out_dir}/build.ninja")
endforeach ()

if(UNIX AND NOT APPLE)
	set (SKIA_WARNING_FLAGS "\\\"-Wno-array-parameter\\\"")
	if (CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 16.0.0)
		string (APPEND SKIA_WARNING_FLAGS ", \\\"-Wno-unsafe-buffer-usage\\\", \\\"-Wno-cast-function-type-strict\\\"")
	endif ()
	set (SKIA_SYSTEM_HARFBUZZ "skia_use_system_harfbuzz=true")
	find_library (HarfBuzz_subset_LIBRARY NAMES harfbuzz-subset)
	if(SKIA_USE_SYSTEM_HARFBUZZ AND NOT HarfBuzz_subset_LIBRARY)
		set (SKIA_USE_SYSTEM_HARFBUZZ OFF CACHE BOOL "HarfBuzz >= 3.0 required" FORCE)
		message (WARNING "Building Skia using the internal version of HarfBuzz")
	endif ()
	if (NOT SKIA_USE_SYSTEM_HARFBUZZ)
		set (SKIA_SYSTEM_HARFBUZZ "skia_use_system_harfbuzz=false")
	endif ()
	if (CMAKE_C_COMPILER_TARGET)
		set (SKIA_COMPILER_TARGET ", \\\"--target=${CMAKE_C_COMPILER_TARGET}\\\", \\\"--sysroot=${CMAKE_SYSROOT}\\\", \\\"-I${CMAKE_SYSROOT}/usr/include\\\", \\\"-I${CMAKE_SYSROOT}/usr/include/freetype2\\\", \\\"-I${CMAKE_SYSROOT}/usr/aarch64-linux-gnu/include\\\"")
		set (SKIA_SYSTEM_FREETYPE_INCLUDES "skia_use_system_freetype_includes=false")
	endif ()

	set (SKIA_GRAPHICS_IMPLEMENTATION "")
	if ("opengles2" IN_LIST skia_FIND_COMPONENTS)
		string (APPEND SKIA_GRAPHICS_IMPLEMENTATION "skia_use_gl=true skia_use_egl=true skia_gl_standard=\\\"gles\\\" ")
	else ()
		string (APPEND SKIA_GRAPHICS_IMPLEMENTATION "skia_use_gl=false ")
	endif ()
	if ("vulkan" IN_LIST skia_FIND_COMPONENTS)
		string (APPEND SKIA_GRAPHICS_IMPLEMENTATION "skia_use_vulkan=true")
	else ()
		string (APPEND SKIA_GRAPHICS_IMPLEMENTATION "skia_use_vulkan=false")
	endif ()
	
	set (SKIA_ARGS_${VENDOR_TARGET_ARCHITECTURE}
		"target_cpu=\\\"${VENDOR_TARGET_ARCHITECTURE}\\\" extra_cflags=[${SKIA_WARNING_FLAGS} ${SKIA_COMPILER_TARGET}] extra_cflags_cc=[${SKIA_WARNING_FLAGS}] ${SKIA_SYSTEM_HARFBUZZ} ${SKIA_SYSTEM_FREETYPE_INCLUDES} ${SKIA_GRAPHICS_IMPLEMENTATION} skia_use_system_freetype2=true skia_use_system_libjpeg_turbo=true skia_use_system_libpng=true skia_use_system_icu=true"
	)
	
	foreach (flavor ${skia_flavors})
		set (filecontent "${filecontent}
			echo \"Building Skia (${flavor})\"
			BUILD_DIR=./${skia_outdir_${flavor}}
			mkdir -p \${BUILD_DIR}
			${SKIA_PRE_GN}
			export ARGS=\"--args=${SKIA_SHARED_ARGS} ${SKIA_ARGS_${flavor}}\"
			echo \${ARGS} | xargs -0 -t \"${SKIA_GN}\" gen \${BUILD_DIR}
			${SKIA_POST_GN}
			${NINJA} -C \${BUILD_DIR}
		")
	endforeach ()

elseif(APPLE)
	set (SKIA_WARNING_FLAGS "\\\"-Wno-nullable-to-nonnull-conversion\\\"")
	set (SKIA_PRE_GN "export PATH=\"${skia_SOURCE_DIR}:\$PATH\"")
	STRING (CONCAT SKIA_ARGS "${SKIA_SHARED_ARGS}")
	STRING (CONCAT SKIA_ARGS "skia_use_metal=true skia_use_gl=false " "${SKIA_ARGS}")

	set (filecontent "${filecontent}
		set -e
		${SKIA_PRE_GN}

		if [ \$PLATFORM_FAMILY_NAME = \"iOS\" ] ; then
			if [ \$PLATFORM_NAME = \"iphonesimulator\" ] ; then
				ARGS=\"${SKIA_ARGS} target_os=\\\"ios\\\" ios_use_simulator=true\"
				EXTRA_CFLAGS=\"${SKIA_WARNING_FLAGS}, \\\"-DSK_USE_CG_ENCODER\\\", \\\"-miphoneos-version-min=\${IPHONEOS_DEPLOYMENT_TARGET}\\\", \\\"--target=\${NATIVE_ARCH_ACTUAL}-apple-ios-simulator\\\"\"
			else
				ARGS=\"${SKIA_ARGS} target_os=\\\"ios\\\"\"
				EXTRA_CFLAGS=\"${SKIA_WARNING_FLAGS}, \\\"-DSK_USE_CG_ENCODER\\\", \\\"-miphoneos-version-min=\${IPHONEOS_DEPLOYMENT_TARGET}\\\"\"
			fi
		else
			ARGS=\"${SKIA_ARGS}\"
			EXTRA_CFLAGS=\"${SKIA_WARNING_FLAGS}, \\\"-DSK_USE_CG_ENCODER\\\", \\\"-mmacosx-version-min=\${MACOSX_DEPLOYMENT_TARGET}\\\"\"
		fi

		echo \"Building for architectures: \${ARCHS}\"
		for ARCH in \${ARCHS}; do
			if [ \$PLATFORM_NAME = \"iphonesimulator\" ] ; then
				ARCH=\"\${NATIVE_ARCH_ACTUAL}\"
			fi
			echo \"Building \${ARCH}\"
			NINJA_BUILD_DIR=./out/cmake_\${PLATFORM_NAME}_${buildtype}_\${ARCH}
			THEARGS=\"--args=\${ARGS} target_cpu=\\\"\${ARCH}\\\" extra_cflags=[\${EXTRA_CFLAGS}, \\\"-arch\\\", \\\"\$ARCH\\\"] extra_asmflags=[\\\"-arch\\\", \\\"\$ARCH\\\"]\"
			echo \${THEARGS} | xargs -0 -t \"${SKIA_GN}\" gen \${NINJA_BUILD_DIR}
			${NINJA} -C \${NINJA_BUILD_DIR}
		done
	")
	foreach (skia_lib ${skia_outputs})
		get_filename_component (skia_lib_name ${skia_lib} NAME)
		set (filecontent "${filecontent}
			THINFILES=\"\"
			CHANGED=\"\"
			for ARCH in \${ARCHS}; do
				NINJA_BUILD_DIR=./out/cmake_\${PLATFORM_NAME}_${buildtype}_\${ARCH}
				THINFILES=\"\${THINFILES} \${NINJA_BUILD_DIR}/${skia_lib_name}\"
				if [ -f \"${skia_lib}\" ]; then
					if [ \"\${NINJA_BUILD_DIR}/${skia_lib_name}\" -nt \"${skia_lib}\" ];  then
						CHANGED=1
					fi
				else
					CHANGED=1
				fi
			done
			if [ \$CHANGED ]; then
				echo \"Assembling ${skia_lib_name}\"
				lipo \${THINFILES} -create -output ${skia_lib}
			fi
		")
	endforeach ()
	
endif ()

file (WRITE ${CMAKE_CURRENT_BINARY_DIR}/tmp/build_skia.sh "${filecontent}")

file (COPY ${CMAKE_CURRENT_BINARY_DIR}/tmp/build_skia.sh
	DESTINATION ${CMAKE_CURRENT_BINARY_DIR}
	FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
)

add_custom_command (OUTPUT ${skia_outputs}
	COMMAND ${CMAKE_CURRENT_BINARY_DIR}/build_skia.sh
	WORKING_DIRECTORY "${skia_SOURCE_DIR}"
	BYPRODUCTS ${skia_byproducts}
	VERBATIM USES_TERMINAL
	DEPENDS ${SKIA_GN}
)
add_custom_target (build_skia
	DEPENDS ${skia_outputs}
)
if (${CMAKE_VERSION} VERSION_GREATER_EQUAL "3.20")
	target_sources (build_skia PRIVATE ${CMAKE_CURRENT_LIST_FILE})
endif ()
set_target_properties (build_skia PROPERTIES 
	USE_FOLDERS ON
	FOLDER libs
)
if(APPLE)
	set_target_properties (build_skia PROPERTIES 
		XCODE_ATTRIBUTE_ARCHS "$(ARCHS_STANDARD)"
		XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH "${CMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH}"
	)
endif ()

foreach (flavor ${skia_flavors})
	add_library (skia_${flavor} SHARED IMPORTED GLOBAL)
	add_dependencies (skia_${flavor} build_skia)
	set_target_properties (skia_${flavor} PROPERTIES
		IMPORTED_LOCATION "${skia_output_${flavor}}"
		INTERFACE_INCLUDE_DIRECTORIES "${skia_SOURCE_DIR}"
	)

	add_library (skshaper_${flavor} SHARED IMPORTED GLOBAL)
	add_dependencies (skshaper_${flavor} build_skia)
	set_target_properties (skshaper_${flavor} PROPERTIES
		IMPORTED_LOCATION "${skshaper_output_${flavor}}"
		INTERFACE_INCLUDE_DIRECTORIES "${skia_SOURCE_DIR}"
	)
	
	add_library (skunicode_${flavor} SHARED IMPORTED GLOBAL)
	add_dependencies (skunicode_${flavor} build_skia)
	set_target_properties (skunicode_${flavor} PROPERTIES
		IMPORTED_LOCATION "${skunicode_output_${flavor}}"
		INTERFACE_INCLUDE_DIRECTORIES "${skia_SOURCE_DIR}"
	)
	
	add_library (skparagraph_${flavor} SHARED IMPORTED GLOBAL)
	add_dependencies (skparagraph_${flavor} build_skia)
	set_target_properties (skparagraph_${flavor} PROPERTIES
		IMPORTED_LOCATION "${skparagraph_output_${flavor}}"
		INTERFACE_INCLUDE_DIRECTORIES "${skia_SOURCE_DIR}"
	)
	
	if (SKIA_DEBUG)
		target_compile_definitions (skia_${flavor} INTERFACE SK_DEBUG=1)
	else ()
		target_compile_definitions (skia_${flavor} INTERFACE SK_RELEASE=1)
	endif ()
	
	list (APPEND SKIA_LIBRARIES skia_${flavor} skshaper_${flavor} skunicode_${flavor} skparagraph_${flavor})
endforeach ()


