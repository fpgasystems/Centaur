
#include "fpgaapi.h"
#include <iostream>
#include <fstream>

WorkloadManager::WorkloadManager(FPGA * p_fpga)
{

	parent_fpga = p_fpga;
  // Set up command queues
	for(int i = 0; i < NUM_FTHREADS; i++)
	{
    printf(" allocate job queue in workload manager\n");
    unsigned int q_ptr_phys;
		job_queue[i]  = reinterpret_cast<FQueue<OneCL>*>( p_fpga->alloc_job_queue(q_ptr_phys) );
    //printf("job queue#%i at: %p\n", i, job_queue[i]);

  	::memset(job_queue[i], 0, sizeof(FQueue<OneCL>));
      
  	job_queue[i]->m_buffer  = reinterpret_cast<OneCL*>( (unsigned char*)(job_queue[i]) + 
                                                        sizeof(FQueue<OneCL>));
  	job_queue[i]->m_capacity            = JOB_QUEUE_SIZE;
    job_queue[i]->m_capacity_bytes      = JOB_QUEUE_SIZE * sizeof(struct OneCL);
  	job_queue[i]->update_bytes_rate     = 2048;
    job_queue[i]->m_crb_code            = FQUEUE_VALID_CODE;
    job_queue[i]->synch_size            = sizeof(struct OneCL);

  	job_queue[i]->m_producer_idx        = 0;
  	job_queue[i]->m_producer_bytes      = 0;
  	job_queue[i]->m_producer_done       = false;
    job_queue[i]->m_producer_code       = FQUEUE_PRODUCER_VALID_CODE;

  	job_queue[i]->m_consumer_idx        = 0;
  	job_queue[i]->m_consumer_bytes      = 0;

  	
  	//
  	queue_code[i]                   = 0;
    //
    jqueue_base_phys[i]             = q_ptr_phys >> 6;
	}
  // 
  printf("job queues allocated!\n");
	
  // setup queues codes
  for(int i = 0; i < NUM_FTHREADS; i++)
  {
  	unsigned int code = p_fpga->get_config_opcode(i);
  	for(int j = 0; j < NUM_FTHREADS; j++)
  	{
  		if(queue_code[j] == 0)
  		{
  			queue_code[j] = code;
  			break;
  		}
  		else if( queue_code[j] == code) break;
  	}
  }

  // Set start_fpga_wlm_cmd
  printf(" set up the start FPGA command\n");
  uint32_t q_size = JOB_QUEUE_SIZE << 16;

  q_size |= (0x0000FFFF & (sizeof(FQueue<OneCL>) >> 6));
  //
  ::memset(&start_fpga_wlm_cmd, 0, sizeof(OneCL));
  
  printf("set start commands fields\n");
  start_fpga_wlm_cmd.dw[0] = (0x00010000) | (uint32_t)(START_JOB_MANAGER_CMD & 0x0000FFFF);
  for(int i = 0; i < NUM_FTHREADS; i++)
  {
    // 96-bits: queue size, code, addr
    start_fpga_wlm_cmd.dw[1+(3*i + 0)] = jqueue_base_phys[i];
    start_fpga_wlm_cmd.dw[1+(3*i + 1)] = (uint32_t)(queue_code[i]);
    start_fpga_wlm_cmd.dw[1+(3*i + 2)] = (uint32_t)(q_size);
  }
  printf(" workload manager allocated\n");
  
}
//**********************************************************************************//
WorkloadManager::~WorkloadManager()
{

}
//**********************************************************************************//
int WorkloadManager::get_job_queue_index( int opcode )
{
  for(int i = 0; i < NUM_FTHREADS; i++)
  {
    if( opcode == queue_code[i] ) return i;
  }
  return -1;
}
//**********************************************************************************//
/*
   enqueue_job: when 1 fthread is passed: a single fthread job request is enqueued
                when multiple fthreads passed it enqueue a pipeline job request. 
                Currently pipelining of two fthreads is only supported. 
*/
bool WorkloadManager::enqueue_job(FthreadRec * t_thread[], int num_threads, uint32_t code)
{
  // It fails if more than 2 fthreads are pipelined
  if( num_threads > 2 ) return false;
  //
  struct OneCL cmd_CL;
  ::memset(&cmd_CL, 0, sizeof(OneCL));

  unsigned char * wsptr = t_thread[0]->parent()->get_ws_base_virt();

  // get the job queue for src fthread
  int job_type = get_job_queue_index(t_thread[0]->get_opcode());

  if( job_type == -1 ) return errlog(ERR_JOB_TYPE_NOT_SUPPORTED);
  
  // destination job if two fthreads passed
  int dst_job_type = get_job_queue_index(t_thread[num_threads-1]->get_opcode());

  unsigned int codew = ((dst_job_type << 1) & 0x0000000E) | code;

  cmd_CL.dw[0] = (uint32_t)(codew);

  for(int i = 0; i < num_threads; i++)
  {
    cmd_CL.dw[7*i + 1] = (uint32_t)(uint64_t(t_thread[i]->get_status()));
    cmd_CL.dw[7*i + 2] = (uint32_t)(uint64_t(t_thread[i]->get_status()) >> 32);
    cmd_CL.dw[7*i + 3] = (uint32_t)(uint64_t(t_thread[i]->get_cfg()));
    cmd_CL.dw[7*i + 4] = (uint32_t)(uint64_t(t_thread[i]->get_cfg()) >> 32);
    cmd_CL.dw[7*i + 5] = (uint32_t)(t_thread[i]->get_cfg_size());
    cmd_CL.dw[7*i + 6] = (uint32_t)(uint64_t(t_thread[i]->get_WrFIFOPtr() - wsptr) >> 6);
    cmd_CL.dw[7*i + 7] = (uint32_t)(uint64_t(t_thread[i]->get_RdFIFOPtr() - wsptr) >> 6);
  }
 
  queue_mutex[job_type].lock();

  while( !job_queue[job_type]->push(cmd_CL) );

  queue_mutex[job_type].unlock();

  return true;
}
