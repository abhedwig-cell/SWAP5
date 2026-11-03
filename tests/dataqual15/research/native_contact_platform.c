/* Research link compatibility for dormant legacy POSIX-codec procedures.
 * The exercised macro codec uses the admitted sibling-file publisher instead.
 * _commit really flushes a regular descriptor; unsupported descriptors fail.
 * This does not qualify the dormant codecs' Windows directory/rename protocol.
 */
#ifdef _WIN32
#include <io.h>
int fsync(int descriptor) { return _commit(descriptor); }
#endif
