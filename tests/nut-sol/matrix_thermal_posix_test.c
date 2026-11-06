/* Qualification only; preserve the real restart publisher's stage6 semantics. */
#include <stdlib.h>
#include <string.h>
int swap5_restart_publish_real(const char *,const char *);
int swap5_restart_publish_test(const char *,const char *,int);
int swap5_restart_publish(const char *pending,const char *target) {
 static unsigned int seen;
 const char *match=getenv("MTPUB_TARGET"),*fault=getenv("MTPUB_FAIL");
 int selected=match&&!strcmp(match,target)&&++seen==1;
 return selected&&fault?swap5_restart_publish_test(pending,target,atoi(fault)):swap5_restart_publish_real(pending,target);
}
int matrix_bad_logical(void) {
 static int calls;const char *value=getenv("MT_BAD_LOGICAL");
 return value&&calls++==0?atoi(value):0;
}
