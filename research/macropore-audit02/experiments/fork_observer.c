#define _GNU_SOURCE
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <link.h>
#include <string.h>
int s5_shadow_begin(void){pid_t p=fork();int s=0;if(!p){alarm(3);return 0;}if(p<0)return -1;while(waitpid(p,&s,0)<0)if(errno!=EINTR)return -2;return WIFEXITED(s)&&WEXITSTATUS(s)==0?1:-3;}
void s5_shadow_end(void){_exit(0);}
int64_t audit_hash_(void*a,int*n){uint64_t h=1469598103934665603ULL;unsigned char*p=a;for(int i=0;i<*n*8;i++){h^=p[i];h*=1099511628211ULL;}return h;}
static uintptr_t baseaddr;
static int base(struct dl_phdr_info*i,size_t s,void*d){if(!i->dlpi_name||!*i->dlpi_name){baseaddr=i->dlpi_addr;return 1;}return 0;}
int64_t audit_macrohash_(void){dl_iterate_phdr(base,0);FILE*f=fopen(getenv("MACRO02_SYMBOLS"),"r");if(!f)abort();unsigned long long a,s;char name[256];uint64_t h=1469598103934665603ULL;while(fscanf(f,"%llx %llx %255s",&a,&s,name)==3){if(!strstr(name,"__mod_macropore_MOD_")&&!strstr(name,"__mod_swap_mp_MOD_"))continue;unsigned char*p=(void*)(baseaddr+a);for(size_t i=0;i<s;i++){h^=p[i];h*=1099511628211ULL;}}fclose(f);return h;}
