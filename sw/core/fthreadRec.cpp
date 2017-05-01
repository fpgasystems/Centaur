#include "fpgaapi.h"
#include <iostream>

 #include <fstream>

//**********************************************************************************//
//**************************                                ************************//
//*********************        FthreadRec Implementation         *******************//
//**************************                                ************************//
//**********************************************************************************//
FthreadRec::FthreadRec()
{
   parent_process_ID = -1;
   config_params     = NULL;
   status_line       = NULL;
   uID               = -1;
   RdFIFOPtr         = 0;
   WrFIFOPtr         = 0;
   name              = std::string("t_name");
}
//**********************************************************************************//
FthreadRec::~FthreadRec()
{

  ::memset(status_line, 0, sizeof(struct FTStatus));

  status_line        = NULL;
  config_params      = NULL;
  config_struct_size = 0;
}
//**********************************************************************************//
FthreadRec::FthreadRec(FthreadRec * t_rec)
{
  parent_process_ID   = t_rec->parent_process_ID;
  config_params       = t_rec->config_params;
  config_struct_size  = t_rec->config_struct_size;
  uID                 = t_rec->uID;
  parent_fpga         = t_rec->parent_fpga;
  name                = std::string("t_name");
  opcode              = t_rec->opcode;
  retPtr              = t_rec->retPtr;

  RdFIFOPtr           = t_rec->RdFIFOPtr;
  WrFIFOPtr           = t_rec->WrFIFOPtr;

  status_line       = new FTStatus;
  
  memcpy(status_line, t_rec->status_line, sizeof(struct FTStatus));
}
//**********************************************************************************//
void FthreadRec::init(int id, int pid, FPGA* parent)
{
  parent_process_ID = pid;
  uID               = id;
  parent_fpga       = parent;
}
//**********************************************************************************//
bool FthreadRec::setFThreadRec(unsigned int code, unsigned char* cfg_s, 
                               unsigned int cfg_size, void* ret)
{

  opcode              = code;

  retPtr              = ret;
  
  config_params       = cfg_s;
  config_struct_size  = cfg_size;

  if(status_line == NULL) 
  {
    void* s_ptr = parent_fpga->malloc( sizeof(FTStatus) );
    status_line = reinterpret_cast<FTStatus*>( s_ptr );
  }
  ::memset(status_line, 0, sizeof(FTStatus));
}
//**********************************************************************************//
void FthreadRec::reset()
{
  ::memset(status_line, 0, sizeof(FTStatus));

  config_params      = NULL;
  config_struct_size = 0;
  opcode             = 0;
}
