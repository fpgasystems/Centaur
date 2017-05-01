
#ifndef __FTHREAD_REC_H__
#define __FTHREAD_REC_H__


class FPGA;

struct FTStatus
{
  // CL #1: State, performance, AFU debug messages
  union {
      uint32_t          qword0[16];      // make it a whole cacheline
      struct {
         uint32_t       state;          
         uint32_t       reads;           
         uint32_t       writes; 
         uint32_t       exec_cycles;
         uint32_t       ConfigCycles;
         uint32_t       TerminatingCycles;
         uint32_t       ReadCycles;
         uint32_t       ReadyCycles;
         uint32_t       afu_counters[8];
      };
   };
};

class FthreadRec{
public:
   FthreadRec();
   FthreadRec( FthreadRec * t_rec );
   ~FthreadRec();

  bool setFThreadRec(unsigned int code, unsigned char* cfg_s, 
                     unsigned int cfg_size, void* ret);
  void init(int id, int pid, FPGA* parent);
  void reset();


  unsigned char* get_cfg()      {  return config_params;       }
  int            get_cfg_size() {  return config_struct_size;  }
  int            get_id()       {  return uID;                 }
  FTStatus*      get_status()   {  return status_line;         }
  int            get_opcode()   {  return opcode;              }
  FPGA*          parent()       {  return parent_fpga;         }

  void*          get_retPtr()   {  return retPtr;              }

  unsigned char* get_WrFIFOPtr(){  return WrFIFOPtr;  }
  unsigned char* get_RdFIFOPtr(){  return RdFIFOPtr;  }

  void setRdFIFOPtr(unsigned char * fptr){  RdFIFOPtr = fptr;  }
  void setWrFIFOPtr(unsigned char * fptr){  WrFIFOPtr = fptr;  }

protected:
  std::string           name;
  int                   uID;
  int                   opcode;
  int                   parent_process_ID;

  int                   config_struct_size;
  unsigned char*        config_params;
  FTStatus*             status_line;

  void*                 retPtr;

  unsigned char*        RdFIFOPtr;
  unsigned char*        WrFIFOPtr;

  FPGA*                 parent_fpga;

};

#endif