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
 
#include "fpgaapi.h"
//**********************************************************************************//
void _DumpCL( void * pCL) 
{
   uint32_t *pu32 = reinterpret_cast<uint32_t*>(pCL);
  
   std::cout << std::dec;
   std::cout << "Status: " << pu32[0] << std::endl;
   std::cout << "Reads: " << pu32[1] << std::endl;
   std::cout << "Writes: " << pu32[2] << std::endl;
   std::cout << "Execution cycles: " << pu32[3] << std::endl;
   
   std::cout << std::hex << std::setfill('0') << std::uppercase;
   for( int i = 4; i < ( CL(1) / sizeof(uint32_t)); ++i )
   {
       std::cout << "0x" << std::setw(8) << pu32[i] << " " << std::endl;
   }
   std::cout <<"" << std::nouppercase << std::endl;
}  // _DumpCL
//**********************************************************************************//
 double get_time()
{
  struct timeval t;
  struct timezone tzp;
  gettimeofday(&t, &tzp);
  return t.tv_sec + t.tv_usec*1e-6;
}
//**********************************************************************************//
bool errlog(unsigned int err_code)
{
  switch( err_code )
  {
    case ERR_HWSRV_ALLOC_FAILED:
      std::cout << "\n ERROR:  Allocating Hardware Service Failed \n";
    break;
    case ERR_WS_ALLOC_FAILED:
      std::cout << "\n ERROR:  Allocating Shared Memory Space Failed \n";
    break;
    case ERR_TRANS_INIT_FAILED:
      std::cout << "\n ERROR:  Establishing link to FPGA Failed \n";
    break;
    case ERR_CONFIG_OPS_UNKNWON:
      std::cout << "\n ERROR:  Cannot Retrieve Configured AFUs Codes from the FPGA \n";
    break;
    case ERR_JOB_TYPE_NOT_SUPPORTED:
      std::cout << "\n ERROR:  Requesting Non Supported Job Type \n";
    break;
    default:
      std::cout << "\n Unknown Error Type \n";
  }

  return false;
}