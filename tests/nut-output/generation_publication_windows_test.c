/* Qualification-only interception. Production has no environment fault switch. */
#include <stdlib.h>
#include <string.h>
#include <windows.h>
int swap5_generation_publish_real(const char *,const char *);
int swap5_generation_publish_test(const char *,const char *,int);
static void pause_point(void) {
 const char *ready=getenv("GPUB_READY"),*release=getenv("GPUB_RELEASE");
 HANDLE a,b;
 if(!ready||!release)ExitProcess(121);
 a=OpenEventA(EVENT_MODIFY_STATE,0,ready);b=OpenEventA(SYNCHRONIZE,0,release);
 if(!a||!b)ExitProcess(122);
 if(!SetEvent(a)||WaitForSingleObject(b,60000)!=WAIT_OBJECT_0)ExitProcess(123);
 CloseHandle(a);CloseHandle(b);
}
int swap5_generation_publish(const char *pending,const char *target) {
 static unsigned int seen;
 const char *match=getenv("GPUB_TARGET"),*count=getenv("GPUB_COUNT"),*action=getenv("GPUB_ACTION"),*fault=getenv("GPUB_FAIL");
 int selected=match&&!strcmp(match,target)&&++seen==(count?(unsigned int)atoi(count):1u);
 int code;
 if(selected&&action&&!strcmp(action,"before"))pause_point();
 code=selected&&fault?swap5_generation_publish_test(pending,target,atoi(fault)):swap5_generation_publish_real(pending,target);
 if(selected&&!code&&action&&!strcmp(action,"after"))pause_point();
 return code;
}
