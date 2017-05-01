#include "fpgaapi.h"


MemoryManager::MemoryManager(unsigned char* virBase, uint64_t wsSize)
   :baseAddr(virBase)
{
	dataBaseAddr = virBase + MB(2);
   sizeChunks1k = 1024;    // 1 MB
   sizeChunks1 = 870;      // 870 MB
   sizeChunks5 = 75;      // 375 MB
   sizeChunks10 = 75;     // 750 MB
   //sizeChunks25 = 25;
   //sizeChunks50 = 20;  
   sizeChunks100 = 20;     // 2000 MB
   
   chunks1k = new MemChunk[sizeChunks1k];
   chunks1  = new MemChunk[sizeChunks1];
   chunks5  = new MemChunk[sizeChunks5];
   chunks10 = new MemChunk[sizeChunks10];
   //chunks25 = new MemChunk[sizeChunks25];
   //chunks50 = new MemChunk[sizeChunks50];
   chunks100 = new MemChunk[sizeChunks100];

   //set shared memory to zero
   ::memset(virBase, 0, wsSize);
   
  //map addresses to chunks
   unsigned char* base = dataBaseAddr;

   for (int i = 0; i < sizeChunks1k; i++)
   {
      chunks1k[i].addr = base;
      chunks1k[i].free = true;
      base += 1024;
   }
   for (int i = 0; i < sizeChunks1; i++)
   {
      chunks1[i].addr = base;
      chunks1[i].free = true;
      base += MB(1);
   }
   for (int i = 0; i < sizeChunks5; i++)
   {
      chunks5[i].addr = base;
      chunks5[i].free = true;
      base += MB(5);
   }
   for (int i = 0; i < sizeChunks10; i++)
   {
      chunks10[i].addr = base;
      chunks10[i].free = true;
      base += MB(10);
   }
   for (int i = 0; i < sizeChunks100; i++)
   {
      chunks100[i].addr = base;
      chunks100[i].free = true;
      base += MB(100);
   }
}

MemoryManager::~MemoryManager()
{
   delete[] chunks1k;
   delete[] chunks1;
   delete[] chunks5;
   delete[] chunks10;
   delete[] chunks100;
}

unsigned char* MemoryManager::get_virt_base() //TODO rename
{
   return baseAddr;
}

void* MemoryManager::malloc(size_t size, size_t* maxsize)
{
   //printChunks();
   
   MemChunk*   list;
   size_t      listSize = 0;
  // printf("Requested size: %i, in MB: %i\n", size, size/MB(1)); fflush(stdout);
   if (size <= 1024)
   {
      list = chunks1k;
      listSize = sizeChunks1k;
      *maxsize = 1024;
   }
   else if (size <= MB(1))
   {
      list = chunks1;
      listSize = sizeChunks1;
      *maxsize = MB(1);
   }
   else if (size <= MB(5))
   {
      list = chunks5;
      listSize = sizeChunks5;
      *maxsize = MB(5);
   }
   else if (size <= MB(10))
   {
      list = chunks10;
      listSize = sizeChunks10;
      *maxsize = MB(10);
   }
   else if (size <= MB(100))
   {
      list = chunks100;
      listSize = sizeChunks100;
      *maxsize = MB(100);
   }
   else
   {
      MSG("malloc: requested size too large, size: "<<size); fflush(stdout);
      return nullptr;
   }
   
   //Loop through list and try to allocate one chunk
   bool exp = true;
   for (int i = 0; i < listSize; i++)
   {
      if(list[i].free)
      {
         //Try to acquire
         if (list[i].free.compare_exchange_weak(exp, false))
         {
            //printf("Memory Chunk allocated: %p\n", list[i].addr); fflush(stdout);
            return list[i].addr;
         }
      }
   }

   MSG("malloc: Could not find a chunk that fits, size: "<<size);//, availablespace"<<availableFreeSpace);
   //printChunks();
   return nullptr;
}

void MemoryManager::free(void* ptr)
{
   MemChunk* list;
   size_t size;

   if (ptr < chunks1[0].addr)
   {
      list = chunks1k;
      size = sizeChunks1k;
   }
   else if (ptr < chunks5[0].addr)
   {
      list = chunks1;
      size = sizeChunks1;
   }
   else if (ptr < chunks10[0].addr)
   {
      list = chunks5;
      size = sizeChunks5;
   }
   else if (ptr < chunks100[0].addr)
   {
      list = chunks10;
      size = sizeChunks10;
   }
   else
   {
      list = chunks100;
      size = sizeChunks100;
   }
   for (int i = 0; i < size; i++)
   {
      if (list[i].addr == ptr)
      {
         //printf("set addr %p to FREE\n", ptr);
         list[i].free = true;
         return;
      }
   }
}

/*
 * Rounds the number of bits up to full cache lines
 */
inline size_t MemoryManager::roundUpToCLs(size_t size)
{
   //Assumption that we are not overflowing 64bit
   return ((size + 63) / 64) * 64;
}

/*
 * Rounds the number of bytes of to full 1MB chunks
 */
inline size_t MemoryManager::roundUpToChunks(size_t size)
{
   //Assumption that we are not overflowing 64bit
   return ((size + 1048575) / 1048576) * 1048576;
}

/*
 * Debug output of the chunk list
 */
void MemoryManager::printChunks()
{
   printf("Base: %p, dataBase: %p\n", baseAddr, dataBaseAddr);
}
