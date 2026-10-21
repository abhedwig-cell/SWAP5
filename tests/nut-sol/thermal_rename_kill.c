#define _GNU_SOURCE
#include <dlfcn.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* Qualification observer only: never linked into a production executable. */
int rename(const char *oldpath, const char *newpath) {
    int (*actual)(const char *, const char *) = dlsym(RTLD_NEXT, "rename");
    const char *target = getenv("SWAP5_THERMAL_KILL_TARGET");
    const char *mode = getenv("SWAP5_THERMAL_KILL_MODE");
    int selected = target && mode && strcmp(target, newpath) == 0;
    if (selected && strcmp(mode, "before") == 0) kill(getpid(), SIGKILL);
    int result = actual(oldpath, newpath);
    if (selected && result == 0 && strcmp(mode, "after") == 0) kill(getpid(), SIGKILL);
    return result;
}
