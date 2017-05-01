#ifndef __MEMORY_MANAGER_H__
#define __MEMORY_MANAGER_H__

struct MemChunk
{
   unsigned char*    addr;
   std::atomic<bool> free;
};

class MemoryManager{
public:
   //TODO btPhysAddr newer used
	MemoryManager(unsigned char* virBase, uint64_t wsSize );
   ~MemoryManager();
	unsigned char* get_virt_base(); //TODO rename to getBase()

   //void* malloc(size_t size);
	void* malloc(size_t size, size_t* maxsize);
	void free(void* ptr);

private:	
   inline uint64_t   roundUpToCLs(uint64_t size);
   inline uint64_t   roundUpToChunks(uint64_t size);
   void              printChunks();

private:
	unsigned char*  baseAddr;
	unsigned char*  dataBaseAddr;

   MemChunk*         chunks1k; 
   MemChunk*         chunks1;
   MemChunk*         chunks5;
   MemChunk*         chunks10;
   //MemChunk*         chunks25;
   //MemChunk*         chunks50;
   MemChunk*         chunks100;

   size_t            sizeChunks1k;
   size_t            sizeChunks1;
   size_t            sizeChunks5;
   size_t            sizeChunks10;
   //size_t            sizeChunks25;
   //size_t            sizeChunks50;
   size_t            sizeChunks100;

};

#endif //__MEMORY_MANAGER_H__
