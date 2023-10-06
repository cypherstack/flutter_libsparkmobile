
#pragma once

#ifndef _GLUECODIUM_FFI_EXPORT
#   if defined(_WIN32) || defined(__CYGWIN)
#       define _GLUECODIUM_FFI_EXPORT __declspec( dllexport )
#   else
#       define _GLUECODIUM_FFI_EXPORT __attribute__( ( visibility( "default" ) ) )
#   endif
#endif
