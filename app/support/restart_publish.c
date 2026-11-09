/* Publish a closed, complete restart stream; owns no physical state or codec.
 * Paths are UTF-8 on Windows, native bytes on POSIX. Source and destination
 * must be siblings (the codecs create destination.pending). No copy fallback.
 * Return stages: 1 path, 2 open, 3 flush, 4 close, 5 replace, 6 directory sync.
 * A failure at stage 6 is AFTER replacement: never report durable success, and
 * never try to roll back a name that may already have become durable.
 */
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#ifdef _WIN32
#include <windows.h>
#define API __declspec(dllexport)
static wchar_t *wide_path(const char *path) {
    int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, NULL, 0);
    wchar_t *wide = n ? malloc((size_t)n * sizeof(*wide)) : NULL;
    if (wide && !MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide, n)) {
        free(wide); wide = NULL;
    }
    return wide;
}
static int replace_file(const wchar_t *src, const wchar_t *dst) {
    unsigned int attempt;
    for (attempt = 0; attempt < 21; ++attempt) {
        DWORD error;
        if (MoveFileExW(src, dst, MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) return 1;
        error = GetLastError();
        /* Short-lived readers, indexing and scanners can block replacement
         * even with FILE_SHARE_DELETE. Bound only this I/O wait to 200 ms;
         * never delete the target or fall back to non-atomic copy semantics.
         */
        if (attempt == 20 || (error != ERROR_ACCESS_DENIED &&
                error != ERROR_SHARING_VIOLATION && error != ERROR_LOCK_VIOLATION)) return 0;
        Sleep(10);
    }
    return 0;
}
#else
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#define API
#endif

static size_t parent_length(const char *path) {
    const char *last = strrchr(path, '/');
#ifdef _WIN32
    const char *back = strrchr(path, '\\');
    if (back && (!last || back > last)) last = back;
#endif
    return last ? (size_t)(last - path + 1) : 0;
}

static int publish(const char *pending, const char *target, int failure, int directory_sync) {
    size_t parent;
    if (!pending || !target || !*pending || !*target || !strcmp(pending, target)) return 1;
    parent = parent_length(target);
    if (parent != parent_length(pending) || memcmp(pending, target, parent)) return 1;
#ifdef _WIN32
    wchar_t *src = wide_path(pending), *dst = wide_path(target);
    HANDLE file;
    int status = 0;
    (void)directory_sync; /* Windows uses write-through replacement. */
    if (!src || !dst) { free(src); free(dst); return 1; }
    file = failure == 2 ? INVALID_HANDLE_VALUE : CreateFileW(src, GENERIC_WRITE,
        FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_FLAG_WRITE_THROUGH, NULL);
    if (file == INVALID_HANDLE_VALUE) status = 2;
    else {
        if (failure == 3 || !FlushFileBuffers(file)) status = 3;
        if (!CloseHandle(file) && !status) status = 4;
        if (failure == 4 && !status) status = 4;
        if (!status && (failure == 5 || !replace_file(src, dst))) status = 5;
    }
    free(src); free(dst);
    return status;
#else
    int fd, directory, status = 0;
    char *folder;
    directory = -1;
    if (directory_sync) {
        /* Open the destination directory before altering the published name. */
        folder = malloc(parent + 2);
        if (!folder) return 1;
        if (parent) { memcpy(folder, target, parent); folder[parent] = '\0'; }
        else { folder[0] = '.'; folder[1] = '\0'; }
        directory = open(folder, O_RDONLY);
        free(folder);
        if (directory < 0) return 2;
    }
    fd = failure == 2 ? -1 : open(pending, O_RDONLY);
    if (fd < 0) status = 2;
    else {
        if (failure == 3 || fsync(fd)) status = 3;
        if (close(fd) && !status) status = 4;
        if (failure == 4 && !status) status = 4;
        if (!status && (failure == 5 || rename(pending, target))) status = 5;
        if (!status && directory_sync && (failure == 6 || fsync(directory))) status = 6;
    }
    if (directory_sync && close(directory) && !status) status = 6;
    return status;
#endif
}

API int swap5_restart_publish(const char *pending, const char *target) {
    return publish(pending, target, 0, 1);
}

/* Complete generation callers publish their staged owners only after success.
 * Retain their existing file-flush + atomic-name contract: no fallible step
 * after replacement. Directory durability remains the restart API contract.
 * Windows Fortran path handling is qualified only for ASCII in this scope.
 */
static int generation_paths(const char *pending, const char *target) {
#ifdef _WIN32
    const unsigned char *p;
    if (!pending || !target) return 0;
    for (p=(const unsigned char *)pending; *p; ++p) if (*p>127) return 0;
    for (p=(const unsigned char *)target; *p; ++p) if (*p>127) return 0;
#else
    (void)pending; (void)target;
#endif
    return 1;
}
API int swap5_generation_publish(const char *pending, const char *target) {
    if (!generation_paths(pending,target)) return 1;
    return publish(pending,target,0,0);
}
#ifdef SWAP5_RESTART_TESTING
API int swap5_generation_publish_test(const char *pending, const char *target, int failure) {
    if (failure && (failure<2 || failure>5)) return 1;
    if (!generation_paths(pending,target)) return 1;
    return publish(pending,target,failure,0);
}
#endif

/* Same reflected CRC-32/ISO-HDLC bytes as the existing native stream codec.
 * Keep the unsigned bit arithmetic explicit: GNU Fortran 16.2 on Windows
 * miscompiles the legacy nested bit loop at O2 (isolated WP0 reproducer).
 * No compiler optimization or physical model setting is relaxed here.
 */
API int32_t swap5_restart_crc32(const int8_t *bytes, size_t count) {
    uint32_t crc = UINT32_MAX;
    int32_t result;
    size_t i;
    unsigned int bit;
    for (i = 0; i < count; ++i) {
        crc ^= (uint8_t)bytes[i];
        for (bit = 0; bit < 8; ++bit)
            crc = (crc >> 1) ^ ((crc & 1) ? UINT32_C(0xedb88320) : 0);
    }
    crc = ~crc;
    memcpy(&result, &crc, sizeof result);
    return result;
}

/* Test-only entry; no environment switch or fault control in production. */
#ifdef SWAP5_RESTART_TESTING
API int swap5_restart_publish_test(const char *pending, const char *target, int failure) {
    return publish(pending, target, failure, 1);
}
#endif
