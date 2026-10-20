#define _DEFAULT_SOURCE
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
/* Fork after exec into this small process: do not inherit Python's RSS peak. */
int main(int argc,char **argv) {
    if(argc<2)return 125;
    pid_t child=fork();
    if(child<0)return 125;
    if(child==0){execvp(argv[1],argv+1);perror("execvp");_exit(127);}
    int status;struct rusage usage;
    if(wait4(child,&status,0,&usage)<0)return 125;
    fprintf(stderr,"PERF01_USAGE %.9f %ld\n",
        usage.ru_utime.tv_sec+usage.ru_utime.tv_usec*1e-6+
        usage.ru_stime.tv_sec+usage.ru_stime.tv_usec*1e-6,usage.ru_maxrss);
    return WIFEXITED(status)?WEXITSTATUS(status):128+WTERMSIG(status);
}
