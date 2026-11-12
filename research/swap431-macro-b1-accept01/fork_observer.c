
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
static int launch(int kind){pid_t p=fork();int s=0;if(p==0){alarm(3);if(kind){char path[64];snprintf(path,sizeof(path),"retry-shadow-%d",kind);if(mkdir(path,0700)&&errno!=EEXIST)_exit(81);if(chdir(path))_exit(82);}return 0;}if(p<0)return -1;while(waitpid(p,&s,0)<0){if(errno!=EINTR)return -2;}return WIFEXITED(s)&&WEXITSTATUS(s)==0?1:-3;}
int audit_fork_begin(void){return launch(0);}
int audit_retry_fork(int kind){return launch(kind);}
void audit_fork_end(void){_exit(0);}
