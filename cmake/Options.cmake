option(ENABLE_ASAN "Enable AddressSanitizer" OFF)
option(ENABLE_UBSAN "Enable UndefinedBehaviorSanitizer" OFF)
option(ENABLE_TSAN "Enable ThreadSanitizer" OFF)
option(ENABLE_LTO "Enable Link Time Optimization" OFF)

function(apply_sanitizers target)
  if(MSVC)
    return()
  endif()

  if(ENABLE_TSAN)
    target_compile_options(${target} PRIVATE -fsanitize=thread
                                             -fno-omit-frame-pointer -g)
    target_link_options(${target} PRIVATE -fsanitize=thread)
  else()
    if(ENABLE_ASAN)
      target_compile_options(${target} PRIVATE -fsanitize=address
                                               -fno-omit-frame-pointer -g)
      target_link_options(${target} PRIVATE -fsanitize=address)
    endif()

    if(ENABLE_UBSAN)
      target_compile_options(${target} PRIVATE -fsanitize=undefined
                                               -fno-omit-frame-pointer -g)
      target_link_options(${target} PRIVATE -fsanitize=undefined)
    endif()

    if(ENABLE_UBSAN)
      target_compile_options(${target} PRIVATE -fno-sanitize-recover=undefined)
    endif()
  endif()
endfunction()

function(apply_lto target)
  if(NOT ENABLE_LTO)
    return()
  endif()

  include(CheckIPOSupported)
  check_ipo_supported(RESULT ipo_ok OUTPUT ipo_err)
  if(ipo_ok)
    set_property(TARGET ${target} PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE)
  else()
    message(WARNING "IPO/LTO not supported: ${ipo_err}")
  endif()
endfunction()
