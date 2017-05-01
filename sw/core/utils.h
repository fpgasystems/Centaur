



#ifndef __UTILS_H__
#define __UTILS_H__

struct OneCL {                      // Make a cache-line sized structure
  uint32_t dw[16];       //    for array arithmetic
};

struct page4kB{
  char pg[4096];
};

struct page1kB{
  char pg[1024];
};

#endif // __UTILS_H__
void _DumpCL( void * pCL) ;
double get_time();
bool errlog(unsigned int err_code);

