#include "fpgaapi.h"
#include <iostream>

 #include <fstream>

//**********************************************************************************//
//**************************                                ************************//
//*********************          Fthread Implementation          *******************//
//**************************                                ************************//
//**********************************************************************************//
Fthread::Fthread(FthreadRec * t_rec)
{ 
  FRecord       = t_rec; 

  t_rec->parent()->enqueueSingleFThread(FRecord);
}
//**********************************************************************************//
Fthread::Fthread(FthreadRec * t_rec, bool enqueue)
{
  
  FRecord = t_rec;

  if( enqueue ) t_rec->parent()->enqueueSingleFThread(FRecord);
  
}
//**********************************************************************************//
Fthread::Fthread(FPGA* fpga_t, unsigned int OpCode, void* afu_config, unsigned int afu_config_size)
{
  
  FRecord = fpga_t->allocateFThreadRecord();

  if(FRecord != NULL)
  {
    FRecord->setFThreadRec(OpCode, reinterpret_cast<unsigned char*>(afu_config), RND_TO_CL(afu_config_size) >> 6, NULL);

    fpga_t->enqueueSingleFThread(FRecord);
  }
}
//**********************************************************************************//
Fthread::~Fthread()
{
   FRecord->reset();

   delete FRecord;
}
//**********************************************************************************//
void Fthread::join()
{
  unsigned char state = 0;
  do
  {
    SleepNano( 200 );

    state = FRecord->get_status()->state;

  }while(state != OPERATOR_DONE_STATE);
  
  // Free FThread resources
  FthreadRec * tmp_rec = FRecord;

  FRecord = new FthreadRec( FRecord );

  tmp_rec->parent()->free(tmp_rec->get_cfg());

  tmp_rec->reset();

  FRecord->parent()->free_fthread(FRecord->get_id());
}
//**********************************************************************************//
double Fthread::timing()
{
  uint64_t cycles = FRecord->get_status()->exec_cycles;
  return (cycles*5.0/1000000.0);
}
//**********************************************************************************//
void Fthread::printStatusLine()
{
   FTStatus* status = FRecord->get_status();
   std::cout << "--------------- STATUS LINE ---------" << std::endl;
   std::cout << "State: " << status->state << std::endl; 
   std::cout << "Reads: " << status->reads << std::endl;
   std::cout << "Writes: " << status->writes << std::endl;
   std::cout << "Execution Cycles: " << status->exec_cycles << std::endl;
   std::cout << "Configuration Cycles: " << status->ConfigCycles << std::endl;
   std::cout << "Terminating Cycles Cycles: " << status->TerminatingCycles << std::endl;
   std::cout << "Read Valid High Cycles: " << status->ReadCycles << std::endl;
   std::cout << "Read Ready High Cycles: " << status->ReadyCycles << std::endl;
   for (int i = 0; i < 8; i++)
   {
      std::cout << "AFU status[" << i << "]: " << status->afu_counters[i] << std::endl;
   }
}

unsigned int  Fthread::readCounter(unsigned int counter_code)
{
  return 0;// status_line->dw[6 + counter_code];
}
