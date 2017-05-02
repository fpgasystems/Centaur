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
 
#ifndef __FPIPE_H__
#define __FPIPE_H__

class Fthread;
class FPGA;

#include "fpgaapi.h"

template<typename T>
class FPipe
{
public:
  FPipe(FPGA* fpga_t, uint32_t pipe_src, uint32_t pipe_dst, uint32_t queue_size = PIPELINE_QUEUE_SIZE, uint16_t page_size = DEFAULT_PAGE_SIZE);
  ~FPipe(){}
  
  uint32_t       getReadAddrCode() { return   m_readAddrCode;   }
  bool           isMemPipe()       { return   m_memPipe;      }
  unsigned char* getFIFOPtr()      { return reinterpret_cast<unsigned char*>(m_pipelineQueue); }

  unsigned char* ptr () { return reinterpret_cast<unsigned char*> (uint64_t(m_readAddrCode << 28) << 32); }

  void pop(T &data);
  void push(T data);


protected:
  uint32_t   m_readAddrCode;
  bool       m_memPipe;
  FPGA*      m_fpga;
  FQueue<T>* m_pipelineQueue;
};

template<typename T>
FPipe<T>::FPipe(FPGA* fpga_t, uint32_t pipe_src, uint32_t pipe_dst, uint32_t queue_size, uint16_t page_size)
{
  m_pipelineQueue = nullptr;
  m_fpga = fpga_t;
  m_memPipe = false;

  uint32_t psize = page_size;
  uint32_t qsize = queue_size;

  if (page_size%(sizeof(T)) > 0)
  {
    psize = (page_size/(sizeof(T)) + 1)*sizeof(T);
  }

  if (queue_size%page_size > 0)
  {
    qsize = page_size*(queue_size/page_size) + page_size;
  }

  if(pipe_src == 0)
  {
    m_memPipe = true;
  }
  else if(pipe_dst == 0)
  {
    m_memPipe = true;
    m_readAddrCode = 0;
  }
  else 
  {
    m_memPipe = true;
    if (m_fpga->adjacentJobs(pipe_src, pipe_dst))
    {
      m_memPipe = false;

    }
    m_readAddrCode = (m_memPipe)? fpga_t->get_addr_code('M') : fpga_t->get_addr_code('D');
  }

  if(m_memPipe)
  {
    m_pipelineQueue = m_fpga->queue_malloc<T>(qsize, psize);
  }
}

template<typename T>
FPipe<T>::~FPipe()
{
   if (m_pipelineQueue != nullptr)
   {
      m_fpga->free(m_pipelineQueue);
   }
}

template<typename T>
void FPipe<T>::pop(T &data)
{
  m_pipelineQueue->pop(data);
}

template<typename T>
void FPipe<T>::push(T data)
{
  m_pipelineQueue->push(data);
}

#endif // __FPIPE_H__
