#ifndef __FPGA_API_H__
#define __FPGA_API_H__

//#define HWAFU

#include <mutex>
#include <thread>
#include <chrono>
#include <iostream>
#include <atomic>

#include <stdlib.h>
#include <math.h>
#include <string.h>

#include "fpga_defs.h"
#include "utils.h"

#include "../platform/platform.h"

#include "fqueue.h"

#include "fthreadRec.h"
#include "fthread.h"
#include "memory_manager.h"
#include "workload_manager.h"

/*
   FPGA data structure is the object representation of the FPGA programming
   environment. It provide member functions that:
    - Establish link with an FPGA device.
    - Create and enqueue jobs on the FPGA.
    - Access CPU-FPGA shared memory space.
*/
class Fthread;
class MemoryManager;
class WorkloadManager;

class FPGA
{

public:

	FPGA();
    
  ~FPGA();
  
  bool            init();
  bool            run();
  bool            release();
  void            terminate();
  //**********************************************************************************//
  //********************  Interface to Platform dependent modules  *******************// 
  //**********************************************************************************//
public:
  bool               allocHWService();
  bool               allocate_workspace(uint64_t ws_size);
  bool               initiateLink();

protected:
  HWService*         srvHndle;  // platform.h

  //**********************************************************************************//
  //******************************* FPGA setup methods *******************************//
  //**********************************************************************************//
public:
  bool               obtainConfiguredOperators();
  void               setUpCommandQueue();
  bool               allocMemManagers();    

  int                get_config_opcode(int idx);
  bool               adjacentJobs(uint32_t J1, uint32_t J2);
protected:
  // List of currently configured operators
  unsigned int       configuredOperators[NUM_FTHREADS];
  unsigned char*     dsm_base;
  //**********************************************************************************//
  //**************************** Interface to Workload Manager ***********************//
  //**********************************************************************************//
public:
  unsigned char*     alloc_job_queue(unsigned int &q_ptr_phys);
  bool               enqueueSingleFThread(FthreadRec* ftRec);
  bool               enqueuePipelineJob(FthreadRec* src, FthreadRec* dst, uint32_t code);

protected:
  WorkloadManager*   wl_manager;
  unsigned int       job_queues_count;
  //**********************************************************************************//
  //*********************** Interface to Memory Manager ******************************//
  //**********************************************************************************//
public:  
  void*              realloc(void* dstruct, size_t size);
  void*              malloc(size_t size);
  void*              malloc(size_t size, size_t* maxsize);
  template <typename T> FQueue<T> * queue_malloc(size_t size, uint32_t syncSize);
  void               free(void * ptr);
  unsigned char*     get_ws_base_virt();
  unsigned char*     get_ws_base_phys();
  uint64_t           get_ws_size();
  void               computeAddressCodes();
  uint32_t           get_addr_code(char ty);

protected:
  MemoryManager*     m_manager[NUM_MMANAGER];
  unsigned char*     ws_base_virt;
  unsigned char*     ws_base_phys;
  uint64_t           ws_size;

  uint32_t           mem_pipe_read_code;
  uint32_t           direct_pipe_read_code;
  uint32_t           mem_norm_addr_code;
  //**********************************************************************************//
  //***************************** Job Creation/Deletion ******************************//
  //**********************************************************************************//
public:
  FthreadRec*        allocateFThreadRecord();
  FthreadRec*        create_fthread(unsigned int opcode, 
                                    unsigned char* afu_config, 
                                    int cfg_size);
  
  FthreadRec*        create_fthread(unsigned int opcode, 
                                    unsigned char* afu_config, 
                                    int cfg_size, void* ret);
  void               free_fthread(int id);

  //template <typename T> Pipeline * get_pipeline_resource(uint32_t pipe_src, uint32_t pipe_dst);

protected:
  FthreadRec         f_threads[MAX_NUM_ALLOWED_JOBS];
  std::atomic<int>   f_threads_flag[MAX_NUM_ALLOWED_JOBS];            
  
  //**********************************************************************************//
  //********************************* FPGA command queue  ****************************//
  //**********************************************************************************//
public:
  void                enqueue_command(OneCL * cmd);
protected:
  FQueue<OneCL>*      cmd_queue;
  std::mutex          cmd_queue_mutex;
  
};
//**********************************************************************************//
template <typename T>
FQueue<T> * FPGA::queue_malloc(size_t size, uint32_t syncSize){

  FQueue<T> * crb = reinterpret_cast<FQueue<T>*>(this->malloc( sizeof(FQueue<T>) ));

  crb->m_buffer        = reinterpret_cast<T*>(this->malloc(size));

  crb->m_capacity        = size / 64;
  crb->m_capacity_bytes  = size;
  crb->update_bytes_rate = syncSize;
  crb->synch_size        = syncSize;
  crb->m_crb_code        = 0;

  crb->m_producer_idx        = 0;
  crb->m_producer_bytes      = 0;
  crb->m_producer_done       = false;
  crb->m_producer_code       = 0;

  crb->m_consumer_idx        = 0;
  crb->m_consumer_bytes      = 0;

  return crb;
}
//**********************************************************************************//
bool getFPGA(FPGA * fpga);
void fpgaServer(FPGA *fpga);

#endif // __FPGA_API_H__ 
