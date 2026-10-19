#ifndef __STRINGS_H__
#define __STRINGS_H__

#if defined(_WIN32) || defined(_WIN64)
  #include <string.h>

  #define strcasecmp _stricmp

  #define strncasecmp _strnicmp
#else
  #include <strings.h>
#endif

#endif /* __STRINGS_H__ */
