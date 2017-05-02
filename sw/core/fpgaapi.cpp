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
//**************************                                ************************//
//*********************         Constructors/Destructors         *******************//
//**************************                                ************************//
//**********************************************************************************//
FPGA::FPGA()
{  
  // Initializations
  for(int i = 0; i < MAX_NUM_ALLOWED_JOBS; i++)
  {
    f_threads_flag[i]  = 0;
    f_threads[i].init(i, 0, this); 
  }

  job_queues_count = 0;
  ws_size          = 0;
  ws_base_virt     = NULL;
  ws_base_phys     = NULL;
  dsm_base         = NULL;

  srvHndle = new HWService();
}
//**********************************************************************************//
FPGA::~FPGA()
{
  release();
  
  delete srvHndle;
  delete wl_manager;
  
  delete[] m_manager;
}
//**********************************************************************************//
bool FPGA::release()
{
  // SPL Related 
  MSG("Stopping SPL Transaction");
  srvHndle->m_SPLService->StopTransactionContext(TransactionID());
  srvHndle->m_Sem.Wait();
  MSG("SPL Transaction complete");

  srvHndle->m_SPLService->WorkspaceFree(get_ws_base_virt(), TransactionID());
  srvHndle->m_Sem.Wait();
  MSG("End Runtime Client");
  srvHndle->m_runtimeClient->end();
  MSG("Release Succeeded");
  
  return true;
}

//**********************************************************************************//
void FPGA::terminate()
{
  MSG("enqueue terminate command\n");

  OneCL cmd_CL;
  
  ::memset(&cmd_CL, 0, sizeof(OneCL));

  cmd_CL.dw[0] = (uint32_t)(FPGA_TERMINATE_CMD);

  enqueue_command(&cmd_CL);

  SleepMilli(10);
  release();
  MSG("\n FPGA Process Terminated\n");
}
//**********************************************************************************//
void FPGA::computeAddressCodes()
{
  mem_norm_addr_code = (uint32_t)(uint64_t(ws_base_virt) >> 32);
  mem_norm_addr_code = (mem_norm_addr_code >> 28) & 0x0000000F;

  mem_pipe_read_code     = (mem_norm_addr_code - 1) & 0x0000000F;
  direct_pipe_read_code  = (mem_norm_addr_code - 7) & 0x0000000F;

  printf(" addr codes: norm %d, mpipe %d, dpipe %d\n", mem_norm_addr_code, 
    mem_pipe_read_code, direct_pipe_read_code);
  fflush(stdout);
}
//**********************************************************************************//
bool FPGA::init()
{
  MSG("Allocate HW Service");
  if( !allocHWService() ) 
    return errlog(ERR_HWSRV_ALLOC_FAILED);
  
  MSG("Allocate Shared Memory Space");
  uint64_t mysize = uint64_t(4096)*1024*1024;
  if( !allocate_workspace(mysize) )
    return errlog(ERR_WS_ALLOC_FAILED);
  
  MSG("Initialize Memory Managers");
  allocMemManagers();
  //--//
  MSG("Compute address codes");
  computeAddressCodes();

  return true;
}
//**********************************************************************************//
bool FPGA::run()
{
  MSG("Setup Command Queue");
  setUpCommandQueue();

  MSG("Initiate Transaction");
  if( !initiateLink() )
    return errlog(ERR_TRANS_INIT_FAILED);
  
  MSG("Get Supported Ops");
  if( !obtainConfiguredOperators() )
    return errlog(ERR_CONFIG_OPS_UNKNWON);

  MSG("Setup Workload Manager");
  wl_manager = new WorkloadManager(this);

  // 
  enqueue_command( wl_manager->start_cmd() );
  MSG("Hardware Service Handle Obtained Successfully!");

  return true;
}
//**********************************************************************************//
bool getFPGA(FPGA * fpga)
{
  if( ! fpga->init() )
    return false;
  
  if( !fpga->run() )
    return false;

  return true;
}
//**********************************************************************************//
void fpgaServer(FPGA *fpga)
{

  fpga->run();

}
//**********************************************************************************//
//**************************                                ************************//
//*********************          Initialization & Setup          *******************//
//**************************                                ************************//
//**********************************************************************************//
bool FPGA::initiateLink()
{
  if( ! srvHndle->init() ) return false;
  dsm_base = srvHndle->m_AFUDSMVirt;
  printf(" DSM address: %p, %p\n", srvHndle->m_AFUDSMVirt, dsm_base);

  return true;
}
//**********************************************************************************//
bool FPGA::allocHWService()
{
  return srvHndle->allocHWService();
}
//**********************************************************************************//
bool FPGA::allocate_workspace(uint64_t wsz)
{
  std::cout << "Size to allocate in FPGA::allocate_workspace: " << wsz << std::endl;
  if( !srvHndle->allocate_workspace(wsz) ) return false;
  
  ws_base_phys = reinterpret_cast<unsigned char*>(srvHndle->m_AFUCTXPhys);
  ws_base_virt = srvHndle->m_AFUCTXVirt;
  ws_size      = srvHndle->m_AFUCTXSize;
  // TODO: may ws_base_phys is usefull?

  return true;
}
//**********************************************************************************//
bool FPGA::allocMemManagers()
{
  unsigned char* base = ws_base_virt;
  //- TODO: Make one memory manager
  
  for (int i = 0; i < NUM_MMANAGER; i++)
  {
    printf("m_manager[%i], base: %p, size: %d\n", i, base, ws_size/NUM_MMANAGER);
    m_manager[i] = new MemoryManager( base, ws_size/NUM_MMANAGER);
    base += (ws_size/NUM_MMANAGER);
  }
  printf("mem managers allocated successfully\n"); fflush(stdout);
  return true;
}
//**********************************************************************************//
bool FPGA::obtainConfiguredOperators()
{
  OneCL * configOpsLine = reinterpret_cast<OneCL*>(dsm_base + 
                          ALLOC_OPERATORS_DSM_OFFSET*64);

  printf( " look at address: %p\n",(dsm_base + ALLOC_OPERATORS_DSM_OFFSET*64));
  // wait until the FPGA updates configured operators status line
  // TODO: Report error if times out (add timeout)
  while(configOpsLine->dw[0] == 0);

  for(int i = 0; i < NUM_FTHREADS; i++)
  {
    configuredOperators[i] = configOpsLine->dw[i];
  }

  return true;
}
//**********************************************************************************//
int FPGA::get_config_opcode(int idx)
{
  return configuredOperators[idx];
}
//**********************************************************************************//
void FPGA::setUpCommandQueue()
{
  // 
  cmd_queue  = reinterpret_cast<FQueue<OneCL>*>( ws_base_virt );
  ::memset(cmd_queue, 0, sizeof(FQueue<OneCL>));

  printf(" cmd queue at virt: %p, phys: %p\n", ws_base_virt, ws_base_phys);
      
  cmd_queue->m_buffer  = reinterpret_cast<OneCL*>(ws_base_virt + 
                                                  sizeof(FQueue<OneCL>));
  cmd_queue->m_capacity        = CMD_QUEUE_SIZE;
  cmd_queue->m_capacity_bytes  = CMD_QUEUE_SIZE * sizeof(OneCL);
  cmd_queue->update_bytes_rate = 2048;
  cmd_queue->m_crb_code        = FQUEUE_VALID_CODE;
  cmd_queue->synch_size        = sizeof(OneCL);

  cmd_queue->m_producer_idx        = 0;
  cmd_queue->m_producer_bytes      = 0;
  cmd_queue->m_producer_code       = FQUEUE_PRODUCER_VALID_CODE;
  cmd_queue->m_producer_done       = false;

  cmd_queue->m_consumer_idx        = 0;
  cmd_queue->m_consumer_bytes      = 0;

  
  
}
//**********************************************************************************//
//**************************                                ************************//
//*********************        Wrappers for MemoryManager        *******************//
//**************************                                ************************//
//**********************************************************************************//

unsigned char* FPGA::get_ws_base_virt()
{
  return ws_base_virt;
}
//**********************************************************************************//
unsigned char* FPGA::get_ws_base_phys()
{
  return ws_base_phys;
}
//**********************************************************************************//
uint64_t FPGA::get_ws_size()
{
  return ws_size;
}
//**********************************************************************************//
void* FPGA::realloc(void* dstruct, size_t size)
{

  void* dstruct_t = malloc(size, &size);
  memcpy(dstruct_t, dstruct, size);

  return dstruct_t;
}
//**********************************************************************************//
void* FPGA::malloc(size_t size)
{
 // printf("allocating space of size: %d\n", size); fflush(stdout);

 // printf("Allocating memory in FPGA object: %p\n", this); fflush(stdout);
   return malloc(size, &size);
}
//**********************************************************************************//
void* FPGA::malloc(size_t size, size_t* maxsize)
{
   //auto start_time = chrono::high_resolution_clock::now();

   size_t id = 0;

   //printf("call m_manager: %d, %p\n", size, m_manager[id]); fflush(stdout);
   return m_manager[id]->malloc(size, maxsize);

   //auto end_time = chrono::high_resolution_clock::now();
   //std::cout << "Time[us] spend in malloc: " << chrono::duration_cast<chrono::microseconds>(end_time - start_time).count();
} 
//**********************************************************************************//
bool FPGA::adjacentJobs(uint32_t J1, uint32_t J2)
{
 // printf("check ops: %d, %d\n", J1, J2); fflush(stdout);
  for(int i = 0; i < NUM_FTHREADS-1; i++)
  {
    if( configuredOperators[i] == J1)
    {
      if( configuredOperators[i+1] == J2) 
      {
       // printf("Jobs are adjacent\n"); fflush(stdout);
        return true;
      }
    }
  }
  //printf("Jobs are not adjacent\n"); fflush(stdout);
  return false;
}
//**********************************************************************************//
void FPGA::free(void* ptr)
{
   size_t id = 0;
   m_manager[id]->free(ptr);
}

//**********************************************************************************//
//**************************                                ************************//
//*********************          Workload/Jobs Wrappers          *******************//
//**************************                                ************************//
//**********************************************************************************//

bool FPGA::enqueueSingleFThread(FthreadRec* ftRec)
{
  //TODO fix this
  FthreadRec * t_thread[8];
  t_thread[0] = ftRec;

  return wl_manager->enqueue_job(t_thread, 1, 0);
}
//**********************************************************************************//
bool FPGA::enqueuePipelineJob(FthreadRec* src, FthreadRec* dst, uint32_t code)
{
  FthreadRec* t_thread[2];
  int num = 0;
  if (src != nullptr)
  {
    t_thread[num] = src;
    num++;
  }
  if (dst != nullptr)
  {
    t_thread[num] = dst;
    num++;
  }

  wl_manager->enqueue_job(t_thread, num, code);
} 
//**********************************************************************************//
void FPGA::enqueue_command(OneCL * cmd_CL)
{
  printf(" enqueue command:%p\n", cmd_CL);

  cmd_queue_mutex.lock();
  while( !cmd_queue->push(*cmd_CL) );
  cmd_queue_mutex.unlock();
}
//**********************************************************************************//
FthreadRec * FPGA::allocateFThreadRecord()
{
  int          exp        = 0;
  FthreadRec * fthreadRec = NULL;
  bool         success    = false;

  for(int i = 0; i < MAX_NUM_ALLOWED_JOBS; i++)
  {
    if( f_threads_flag[i] == exp ) 
    {
      //Try to swap it to true
      success = true;
      while ( !f_threads_flag[i].compare_exchange_weak(exp, 1) )
      {
         MSG("allocateStatusForOp: CAS fail");
         if ( f_threads_flag[i] == exp )
         {
            success = false;
            break;
         }
      }
      if (success)
      {
         fthreadRec =  &f_threads[i];
         break;
      }
    }
  }

  return fthreadRec;
}
//**********************************************************************************//
FthreadRec * FPGA::create_fthread(unsigned int opcode, 
                                  unsigned char* afu_config, 
                                  int cfg_size, void* ret)
{
  FthreadRec * fthreadRec = allocateFThreadRecord();
  if( fthreadRec == NULL ) {printf(" fthread cannot be allocated\n"); fflush(stdout);}
  if( fthreadRec == NULL ) return NULL;

  fthreadRec->setFThreadRec(opcode, afu_config, RND_TO_CL(cfg_size) >> 6, ret);
  
  // TODO: What happens if the job queue is full
  //if( !enqueue_job(fthreadRec) ) 
   // return NULL;

  return fthreadRec;
}
//**********************************************************************************//
FthreadRec * FPGA::create_fthread(unsigned int opcode, 
                                  unsigned char* afu_config, 
                                  int cfg_size)
{
  FthreadRec * fthreadRec = allocateFThreadRecord();
  if( fthreadRec == NULL ) {printf(" fthread cannot be allocated\n"); fflush(stdout);}
  if( fthreadRec == NULL ) return NULL;

  fthreadRec->setFThreadRec(opcode, afu_config, RND_TO_CL(cfg_size) >> 6, NULL);

  return fthreadRec;
}
//**********************************************************************************//
unsigned char * FPGA::alloc_job_queue(unsigned int &q_ptr_phys)
{
  q_ptr_phys = 0;

  if( job_queues_count >= ALLOWED_JOB_QUEUE_NUM) 
    return NULL;

  unsigned int   jqueue_size = JOB_QUEUE_SIZE*64 + sizeof(FQueue<OneCL>);

  unsigned char* queue_ptr = ws_base_virt + JOP_QUEUE_DSM_OFFSET*64 + 
                             (job_queues_count)*jqueue_size;

  printf("job q count = %i, %d, %p\n", job_queues_count, jqueue_size, queue_ptr);

  q_ptr_phys = JOP_QUEUE_DSM_OFFSET*64 + (job_queues_count)*jqueue_size;

  job_queues_count += 1;
  
  printf( "job queue allocated Successfully\n");
  return queue_ptr;
}
//**********************************************************************************//
void FPGA::free_fthread(int id)
{
  f_threads_flag[id] = 0;
}
//**********************************************************************************//
uint32_t FPGA::get_addr_code(char ty)
{
  if (ty == 'M')
  {
    return mem_pipe_read_code;
  }
  else if (ty == 'D')
  {
    return direct_pipe_read_code;
  }
  else 
  {
    return mem_norm_addr_code;
  }
}
