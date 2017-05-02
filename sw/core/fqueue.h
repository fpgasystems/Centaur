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
 
#ifndef FQUEUE_H
#define FQUEUE_H

//#include <aalsdk/kernel/vafu2defs.h>      // AFU structure definitions (brings in spl2defs.h)
#include <thread>
#include <atomic>

#define FQUEUE_VALID_CODE 0x13579bdf
#define FQUEUE_PRODUCER_VALID_CODE 0x02468ace


template <typename T>
class FQueue{
public: //Everything is public to avoid reordering in memory
  // fields
  union {
        uint64_t          qword0[8];       // make it a whole cacheline
        struct {
            T                      *m_buffer; 
            //btUnsigned32bitInt       m_size;
            volatile uint32_t       m_capacity;
            volatile uint32_t       m_capacity_bytes;
            volatile uint32_t       update_bytes_rate;
            volatile uint32_t       m_crb_code;
            volatile uint32_t       synch_size;
        };
    };

  // producer info
  union {
        uint64_t          qword1[8];       // make it a whole cacheline
        struct {
            volatile uint32_t       m_producer_idx;
            volatile uint32_t       m_producer_bytes;
            volatile uint32_t       m_producer_code;
            volatile bool                          m_producer_done;
        };
  };

  // consumer info
  union {
        uint64_t          qword2[8];       // make it a whole cacheline
        struct {
            volatile uint32_t       m_consumer_idx;
            volatile uint32_t       m_consumer_bytes;
        };
  };
    // Constructor
    //FQueue<T>(ServiceHW *srvHndle, unsigned int capacity); //TODO

  bool push(T value);
  bool pop(T& value);
  bool empty();
  bool full();
  std::size_t size() const;
  std::size_t capacity() const;

  void done();
  bool isDone();
  void reset();

};

/*template <typename T>
FQueue::FQueue(ServiceHW *srvHndle, unsigned int capacity)
{
      unsigned int num_cl = (capacity+63 / 64); //TODO check rounding
      m_buffer          = (btVirtAddr)(srvHndle->malloc(CL(num_cl))); //TODO this should be done by the allocator!!!
      //m_size        = 0;
      m_capacity = capacity;
      m_capacity_bytes = capacity * sizeof(T);

      m_producer_idx = 0;
      m_producer_bytes = 0;
      m_producer_done = false;
      m_consumer_idx = 0;
      m_consumer_bytes = 0;
}*/

// TODO deconstructor

template <typename T>
bool FQueue<T>::push( T value)
{
  // Check if full
  while  ( full() )
  {
  SleepNano(100);
   // return false;
  }
  //insert at end
  atomic_thread_fence(std::memory_order_acquire);
  
  m_buffer[m_producer_idx] = value;
  m_producer_idx           = (m_producer_idx + 1) % m_capacity;
  m_producer_bytes        += sizeof(T);

  atomic_thread_fence(std::memory_order_release);
  return true;
}

template <typename T>
bool FQueue<T>::pop(T & value)
{
  // Check if empty
  while ( empty() & ~isDone() )
  {
    SleepNano(100);
   // return false;
  }
  atomic_thread_fence(std::memory_order_acquire);
  value             = m_buffer[m_consumer_idx];
  m_consumer_idx    = (m_consumer_idx + 1) % m_capacity;
  m_consumer_bytes += sizeof(T);

  atomic_thread_fence(std::memory_order_release);
  
  return true;
}

template <typename T>
bool FQueue<T>::empty()
{

  if( (m_producer_bytes - m_consumer_bytes)  < sizeof(T) )
  {
    return true;

  } 
  return (m_producer_bytes == m_consumer_bytes);
 // return (m_producer_idx == m_consumer_idx);
}

template <typename T>
bool FQueue<T>::full()
{
  if( (m_capacity_bytes - (m_producer_bytes - m_consumer_bytes) ) < sizeof(T) ) return true;
  return ((m_producer_bytes - m_consumer_bytes) == m_capacity_bytes);
}

template <typename T>
size_t FQueue<T>::size() const
{
  return (m_capacity_bytes - (m_producer_bytes - m_consumer_bytes));
}

template <typename T>
size_t FQueue<T>::capacity() const
{
  return m_capacity;
}

template <typename T>
void FQueue<T>::done()
{
   m_producer_done = true;
   m_producer_code = 0xffffffff;
}

template <typename T>
bool FQueue<T>::isDone()
{
   return m_producer_done;
}

template <typename T>
void FQueue<T>::reset()
{
   m_producer_idx    = 0;
   m_producer_bytes  = 0;
   m_producer_done   = false;
   m_consumer_idx    = 0;
   m_consumer_bytes  = 0;
}

#endif
