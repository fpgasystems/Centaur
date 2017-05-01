#ifndef __FPGA_DEF_H__
#define __FPGA_DEF_H__


#ifndef CL
# define CL(x)                     ((x) * 64)
#endif // CL
#ifndef MB
# define MB(x)                     ((x) * 1024 * 1024)
#endif // MB
#ifndef GB
# define GB(x)                     ((x) * MB(1) * 1024)
#endif // GB

#ifndef RND_TO_CL
# define RND_TO_CL(x)              ( ((x+63)/64) * 64)
#endif // RND_TO_CL

#ifdef MSG
# undef MSG
#endif // MSG
#ifndef MSG
 #define MSG(x)                    (std::cout<< x <<std::endl)
#endif // MSG

#ifdef ERR
# undef ERR
#endif // ERR
#ifndef ERR
 #define ERR(x)                    (std::cerr<< x <<std::endl)
#endif // ERR

// Constraints
#define MAX_NUM_SUPPORTED_OPS            32              // Maximum number of supported operators (this is not necessary)

#define APP_WORKSPACE_MAXIMUM_SIZE       MB(4096)        // Maximum allocatable shared memory space

#define MAX_NUM_ALLOWED_JOBS             1024            // Maximum number of operators that can be allocated
#define ALLOWED_JOB_QUEUE_NUM            8
#define JOB_QUEUE_SIZE                   128             // Maximum size of the job queue 

#define CMD_QUEUE_SIZE                   32              // Maximum size of the command queue 

#define NUM_FTHREADS                     4               // Maximum number of physical fthreads 

#define NUM_MMANAGER                     1

#define PIPELINE_QUEUE_SIZE              CL(1024)
#define DEFAULT_PAGE_SIZE                4*1024
//////////////////////////       DSM Layout (4k)  /////////////////////////

// Framework Status Lines
#define AFU_ID_DSM_OFFSET                0      // Reserved by AAL

#define PT_STATUS_DSM_OFFSET             1      // 
#define CTX_STATUS_DSM_OFFSET            2      // 
#define ALLOC_OPERATORS_DSM_OFFSET       3      // List of Configured Operators on the FPGA

//////////////////////////       DSM Layout (2M)  /////////////////////////
// Command Queue
#define CMD_QUEUE_DSM_OFFSET             0          // Command queue start point offset 
#define OP_STATUS_DSM_OFFSET             1024       // Allocated Operators Status Line offset
#define JOP_QUEUE_DSM_OFFSET             64

////////////////////////////////////////////////////////////////////////////
#define OPERATOR_DONE_STATE              0x04
#define OPERATOR_SCHEDULED_STATE         0x02
#define OPERATOR_RUN_STATE               0x01
#define OPERATOR_IDLE_STATE              0x00

//////////////////////////////////////////////////////////////////////////
// FPGA COMMANDS
#define FPGA_TERMINATE_CMD               0x00000001
#define START_JOB_MANAGER_CMD            0x00000002

///////////////////////////////////////////////////////////////////////////
// ERROR CODES
#define ERR_HWSRV_ALLOC_FAILED           0x00000001
#define ERR_WS_ALLOC_FAILED              0x00000002
#define ERR_TRANS_INIT_FAILED            0x00000003
#define ERR_CONFIG_OPS_UNKNWON           0x00000004
#define ERR_JOB_TYPE_NOT_SUPPORTED       0x00000005




#endif // __FPGA_DEF_H__ 
