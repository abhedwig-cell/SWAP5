/* Test-only preload: stop the owned process at a selected publication boundary. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
int rename(const char *oldpath,const char *newpath) {
 static int seen;
 int (*original)(const char *,const char *)=dlsym(RTLD_NEXT,"rename");
 const char *target=getenv("OUTPUT_TEST_TARGET"),*phase=getenv("OUTPUT_TEST_PHASE");
 const char *count=getenv("OUTPUT_TEST_RENAME_COUNT");
 int selected=target&&phase&&count&&!strcmp(newpath,target)&&++seen==atoi(count);
 if(selected&&!strcmp(phase,"before"))raise(SIGSTOP);
 int code=original(oldpath,newpath);
 if(selected&&code==0&&!strcmp(phase,"after"))raise(SIGSTOP);
 return code;
}
