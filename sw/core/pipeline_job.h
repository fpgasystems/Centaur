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
 
#ifndef __FPIPELINEJOB_H__
#define __FPIPELINEJOB_H__

class Fthread;
class FPGA;

#include "fpgaapi.h"
#include "fpipe.h"

template<typename T>
class PipelineJob
{
public: 
  PipelineJob(FthreadRec* src, FPipe<T>* pipe, FthreadRec* dst);
  PipelineJob(FPipe<T>* pipe, FthreadRec* dst);
  PipelineJob(FthreadRec* src, FPipe<T>* pipe);
  ~PipelineJob();

  void          join();
  double        timing();
  void          printStatusLine();

  Fthread*     getSrc() { return m_srcThread; }
  Fthread*     getDst() { return m_dstThread; }

protected:
  FPGA*         m_fpga; 
  Fthread*      m_srcThread;
  Fthread*      m_dstThread;
};

template<typename T>
PipelineJob<T>::PipelineJob(FthreadRec* srcOp, FPipe<T>* pipe, FthreadRec* dstOp)
{
  m_fpga = srcOp->parent();
  m_srcThread = nullptr;
  m_dstThread = nullptr;

  if (srcOp)
  {
    m_srcThread = new Fthread(srcOp, false);
  }
  if (dstOp)
  {
    m_dstThread = new Fthread(dstOp, false);
  }

  uint32_t code = 0x00000011; 
  if( pipe->isMemPipe() )
  {
    code = code | 0x00080020 | (pipe->getReadAddrCode() << 20);
  }
  else 
  {
    code = code | 0x00040000 | (pipe->getReadAddrCode() << 24);
  }

  if( pipe->isMemPipe() )
  {
    m_srcThread->getFThreadRec()->setWrFIFOPtr( pipe->getFIFOPtr() );
    m_dstThread->getFThreadRec()->setRdFIFOPtr( pipe->getFIFOPtr() );
  }

  m_srcThread->getFThreadRec()->parent()->enqueuePipelineJob(m_srcThread->getFThreadRec(), m_dstThread->getFThreadRec(), code);
}

template<typename T>
PipelineJob<T>::~PipelineJob()
{
   if (m_srcThread != nullptr)
      delete m_srcThread;
   if (m_dstThread != nullptr)
      delete m_dstThread;
}

template<typename T>
PipelineJob<T>::PipelineJob(FPipe<T>* pipe, FthreadRec* dstOp)
{ 
  //assert(dstOp != nullptr);
  m_fpga = dstOp->parent();
  m_srcThread = nullptr;
  m_dstThread = new Fthread(dstOp, false);

  uint32_t code = 0x00000080 | (pipe->getReadAddrCode() << 8);       

  m_dstThread->getFThreadRec()->setRdFIFOPtr( pipe->getFIFOPtr() );

  m_dstThread->getFThreadRec()->parent()->enqueuePipelineJob(nullptr, m_dstThread->getFThreadRec(), code);
}

template<typename T>
PipelineJob<T>::PipelineJob(FthreadRec* srcOp, FPipe<T>* pipe)
{ 
  //assert(srcOp != nullptr);
  m_fpga = srcOp->parent();
  m_srcThread = new Fthread(srcOp, false);
  m_dstThread = nullptr;

  uint32_t code = 0x00000030;       

  m_srcThread->getFThreadRec()->setWrFIFOPtr( pipe->getFIFOPtr() );

  m_srcThread->getFThreadRec()->parent()->enqueuePipelineJob(m_srcThread->getFThreadRec(), nullptr, code);
}

template<typename T>
void PipelineJob<T>::join()
{
  // Release the operator resources  
  if (m_srcThread)
    m_srcThread->join();
  if (m_dstThread)
    m_dstThread->join();
}

template<typename T>
double PipelineJob<T>::timing()
{
  if (m_dstThread)
    return m_dstThread->timing();
  else
    return m_srcThread->timing();
}

template<typename T>
void PipelineJob<T>::printStatusLine()
{
  if (m_srcThread)
  {
    std::cout << "Source FThread STATUS LINE ---------" << std::endl;
    m_srcThread->printStatusLine();
  }

  if (m_dstThread)
  {
    std::cout << "Destination FThread STATUS LINE ---------" << std::endl;
    m_dstThread->printStatusLine();
  }
}

#endif // __FPIPELINEJOB_H__
