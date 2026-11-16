#define _GNU_SOURCE
#include <link.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
static uintptr_t image_base;
static int seen_reject=0,done=0;
static int base(struct dl_phdr_info *i,size_t s,void*d){if(!i->dlpi_name||!*i->dlpi_name){image_base=i->dlpi_addr;return 1;}return 0;}
/* Addresses/sizes are generated from the EXACT linked observer, not its parent. */
void audit_state_(int *stage){
 if(done)return;
 const char *tag;
 if(*stage==0){if(seen_reject){tag="retry";done=1;}else tag="origin";}
 else if(*stage==1){if(seen_reject)return;seen_reject=1;tag="trial";}
 else {if(!seen_reject)return;tag="restored";}
 dl_iterate_phdr(base,NULL);
 FILE *idx=fopen(getenv("MACRO02_SYMBOLS"),"r");if(!idx)abort();
 char path[128],name[256];sprintf(path,"rollback-%s.bin",tag);FILE*out=fopen(path,"wb");
 unsigned long long addr,size;
 while(fscanf(idx,"%llx %llx %255s",&addr,&size,name)==3){if(fwrite((void*)(image_base+addr),1,size,out)!=size)abort();}
 fclose(idx);fclose(out);
}
static int probed=0;
int audit_ready_(void){if(done&&!probed){probed=1;return 1;}return 0;}
void audit_restore_macro_(void){
 dl_iterate_phdr(base,NULL);
 FILE*idx=fopen(getenv("MACRO02_SYMBOLS"),"r");FILE*raw=fopen("rollback-origin.bin","rb");
 if(!idx||!raw)abort();unsigned long long addr,size;char name[256];
 FILE*names=fopen(getenv("MACRO02_RESTORE_NAMES"),"r");if(!names)abort();
 char list[40000]={0},line[256];while(fgets(line,sizeof line,names)){strcat(list,"|");strncat(list,line,strcspn(line,"\n"));strcat(list,"|");}fclose(names);
 while(fscanf(idx,"%llx %llx %255s",&addr,&size,name)==3){
  char find[300];sprintf(find,"|%s|",name);
  if(strstr(list,find)){if(fread((void*)(image_base+addr),1,size,raw)!=size)abort();}else fseek(raw,size,SEEK_CUR);
 }
 fclose(idx);fclose(raw);
}
