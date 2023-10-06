
#include "DartDLInit.h"
#include "dart_api_dl.h"
#include "dart_version.h"
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  const char* name;
  void* function;
} ApiEntry;

typedef struct {
  const int major;
  const int minor;
  const ApiEntry* const functions;
} ApiData;

#define API_DL_DEFINITION(name, R, A) name##_Type name##_DL = NULL;
DART_API_ALL_DL_SYMBOLS(API_DL_DEFINITION)

void*
find_function_pointer(const ApiEntry* entries, const char* name) {
  while (entries->name != NULL) {
    if (strcmp(entries->name, name) == 0) return entries->function;
    entries++;
  }
  return NULL;
}

int32_t
library_dart_dl_initialize(void* data) {
  ApiData* api_data = (ApiData*)data;
  if (api_data->major != DART_API_DL_MAJOR_VERSION) {
    // Minor versions are allowed to be different.
    return -1;
  }

  const ApiEntry* function_pointers = api_data->functions;
#define API_DL_INIT(name, R, A) name##_DL = (name##_Type)(find_function_pointer(function_pointers, #name));
  DART_API_ALL_DL_SYMBOLS(API_DL_INIT)

  return 1;
}

#ifdef __cplusplus
}
#endif
