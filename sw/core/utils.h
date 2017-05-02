/*
 * Copyright (C) 2017 Systems Group, ETHZ

 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at

 * http://www.apache.org/licenses/LICENSE-2.0

 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


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

