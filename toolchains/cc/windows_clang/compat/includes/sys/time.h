#ifndef __SYS_TIME_H__
#define __SYS_TIME_H__

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

#if defined(_WIN32) || defined(_WIN64)

#ifndef _WINSOCK2API_
#include <Winsock2.h> /* timeval */
#endif /* _WINSOCK2API_ */

#include <stdint.h>

struct timezone {
  int tz_minuteswest;
  int tz_dsttime;
};

#else
#  include <sys/time.h>
#endif

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* __SYS_TIME_H__ */