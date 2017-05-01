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
