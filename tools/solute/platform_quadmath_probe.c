/* Private math-runtime discriminator. No installed/default build uses this.
 * Original real32/64 interfaces and Fortran evaluation order are retained;
 * transcendental values are evaluated by GNU libquadmath then rounded back.
 * Runtime/table/source identity and model costs must be qualified separately.
 */
#include <quadmath.h>
#define UNARY(name) \
double name(double x) { return (double)name##q((__float128)x); } \
float name##f(float x) { return (float)name##q((__float128)x); }
UNARY(exp)
UNARY(log)
UNARY(log10)
UNARY(sin)
UNARY(cos)
UNARY(tan)
UNARY(asin)
UNARY(acos)
UNARY(atan)
UNARY(sinh)
UNARY(cosh)
UNARY(tanh)
double pow(double x,double y) { return (double)powq((__float128)x,(__float128)y); }
float powf(float x,float y) { return (float)powq((__float128)x,(__float128)y); }
double atan2(double x,double y) { return (double)atan2q((__float128)x,(__float128)y); }
float atan2f(float x,float y) { return (float)atan2q((__float128)x,(__float128)y); }
