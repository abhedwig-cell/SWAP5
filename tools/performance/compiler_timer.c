/* Diagnostic compiler observer: original compiler argv and exit status retained. */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/resource.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <time.h>
static double stamp(void){struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec+t.tv_nsec*1e-9;}
static double sec(struct timeval t){return t.tv_sec+t.tv_usec*1e-6;}
int main(int argc,char **argv){
 const char *real=getenv("SWAP_TIMER_COMPILER"),*events=getenv("SWAP_TIMER_EVENTS");
 if(!real||!events)return 127;
 int run=getenv("SWAP_TIMER_RUN")!=NULL; int compile=0; const char *source=run?real:"-",*out=NULL;
 for(int i=1;i<argc;i++){if(!strcmp(argv[i],"-c")){compile=1;if(i+1<argc)source=argv[i+1];}if(!strcmp(argv[i],"-o")&&i+1<argc)out=argv[i+1];}
 double began=stamp(); pid_t p=fork();if(p<0)return 127;
 if(!p){argv[0]=(char*)real;execv(real,argv);_exit(127);}
 int status;struct rusage usage;if(wait4(p,&status,0,&usage)<0)return 127;
 int rc=WIFEXITED(status)?WEXITSTATUS(status):128+WTERMSIG(status);
 FILE *f=fopen(events,"a");if(!f)return 127;flock(fileno(f),LOCK_EX);
 fprintf(f,"%s\t%.9f\t%.9f\t%.9f\t%d\t%s",run?"run":(compile?"compile":"link"),stamp()-began,sec(usage.ru_utime),sec(usage.ru_stime),rc,source);
 for(int i=1;i<argc;i++){fprintf(f,"\t%s",argv[i]);}fputc('\n',f);fclose(f);
 const char *copies=getenv("SWAP_TIMER_COPIES");
 if(!rc&&!run&&!compile&&out&&copies){
  /* Independent copies are for native timing only, never qualification reuse. */
  char dest[4096];int index=0;do{snprintf(dest,sizeof(dest),"%s/%d.exe",copies,index++);}while(access(dest,F_OK)==0);
  FILE *in=fopen(out,"rb"),*copy=fopen(dest,"wb");if(!in||!copy)return 127;
  char buf[16384];size_t n;while((n=fread(buf,1,sizeof(buf),in)))if(fwrite(buf,1,n,copy)!=n)return 127;
  fclose(in);fclose(copy);chmod(dest,0700);
  char native[4096];snprintf(native,sizeof(native),"%s.native",out);
  if(rename(out,native))return 127;
  char observer[4096];ssize_t size=readlink("/proc/self/exe",observer,sizeof(observer)-1);if(size<0)return 127;observer[size]=0;
  FILE *script=fopen(out,"w");if(!script)return 127;
  fprintf(script,"#!/bin/sh\nexport SWAP_TIMER_COMPILER='%s'\nexport SWAP_TIMER_RUN=1\nexec '%s' \"$@\"\n",native,observer);
  fclose(script);chmod(out,0700);
 }
 return rc;
}
