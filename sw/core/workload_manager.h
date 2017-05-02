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

 
#ifndef __WORKLOAD_MANAGER_H__
#define __WORKLOAD_MANAGER_H__


class FPGA;

/*
    In the current version where no partial reconfiguration is supported and the 
    AFUs are fixed on the FPGA the workload manager operation is simple:

    On establishing the connection with the FPGA, and receiving the opcodes for 
    configured AFUs a predefined mapping of the queues is established and hence 
    every supported job type is assigned a queue.  

*/
class WorkloadManager{
public:
   WorkloadManager(FPGA * p_fpga);
   ~WorkloadManager();

  
  bool   enqueue_job(FthreadRec * t_thread[], int num_threads, uint32_t code);
  int    get_job_queue_index( int opcode );

  OneCL* start_cmd(){  return &start_fpga_wlm_cmd; }

protected:
  
  FQueue<OneCL>*          job_queue[NUM_FTHREADS];
  unsigned int            queue_code[NUM_FTHREADS];
  std::mutex              queue_mutex[NUM_FTHREADS];

  uint32_t                jqueue_base_phys[NUM_FTHREADS];

  FPGA*                   parent_fpga;

  OneCL                   start_fpga_wlm_cmd;

};

#endif // __WORKLOAD_MANAGER_H__
