/* Qualification-only interception. Production has no environment fault switch. */
#include <stdlib.h>
#include <string.h>
#include <windows.h>
int swap5_restart_publish_real(const char *,const char *);
int swap5_restart_publish_test(const char *,const char *,int);
static void pause_point(void) {
 const char *ready=getenv("MTPUB_READY"),*release=getenv("MTPUB_RELEASE");
 HANDLE a,b;
 if(!ready||!release)ExitProcess(121);
 a=OpenEventA(EVENT_MODIFY_STATE,0,ready);b=OpenEventA(SYNCHRONIZE,0,release);
 if(!a||!b)ExitProcess(122);
 if(!SetEvent(a)||WaitForSingleObject(b,60000)!=WAIT_OBJECT_0)ExitProcess(123);
 CloseHandle(a);CloseHandle(b);
}
int swap5_restart_publish(const char *pending,const char *target) {
 static unsigned int seen;
 const char *match=getenv("MTPUB_TARGET"),*count=getenv("MTPUB_COUNT"),*action=getenv("MTPUB_ACTION"),*fault=getenv("MTPUB_FAIL");
 int selected=match&&!strcmp(match,target)&&++seen==(count?(unsigned int)atoi(count):1u);
 int code;
 if(selected&&action&&!strcmp(action,"before"))pause_point();
 code=selected&&fault?swap5_restart_publish_test(pending,target,atoi(fault)):swap5_restart_publish_real(pending,target);
 if(selected&&!code&&action&&!strcmp(action,"after"))pause_point();
 return code;
}

int matrix_bad_logical(void) {
 static int calls; const char *value=getenv("MT_BAD_LOGICAL");
 return value && calls++==0 ? atoi(value) : 0;
}
