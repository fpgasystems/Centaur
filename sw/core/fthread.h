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
 
#ifndef __FTHREAD_H__
#define __FTHREAD_H__


class FPGA;
class Pipeline;

//***************************************************************************//
class Fthread
{
public:
  Fthread(FthreadRec * t_rec);
  Fthread(FthreadRec * t_rec, bool enqueue);
  Fthread(FPGA* fpga_t, unsigned int OpCode, void* afu_config, unsigned int afu_config_size);

  //Fthread(FthreadRec * src_rec, Pipeline * pipe1, FthreadRec * dst_rec);
  //Fthread(Pipeline * pipe1, FthreadRec * dst_rec);
  //Fthread(FthreadRec * src_rec, Pipeline * pipe1);

  ~Fthread();

  void          join();
  double        timing();
  void          printStatusLine();
  unsigned int  readCounter(unsigned int counter_code);

  FthreadRec * getFThreadRec(){ return FRecord; }

protected:
  
  FthreadRec *  FRecord;  

};

#endif // __FTHREAD_H__
