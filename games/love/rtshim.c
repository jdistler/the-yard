/* Integer-to-float helpers that LuaJIT's ARM interpreter calls by their libgcc names. zig's compiler runtime
 * has them only under their ARM EABI names (__aeabi_l2d and friends), and those use the soft-float calling
 * convention, so these wrappers convert in C: clang emits the __aeabi_ call and returns in d0/s0 as the
 * hard-float ABI wants. Linked into libluajit by games/love/build.sh. */
double __floatdidf(long long a) { return (double)a; }
float __floatdisf(long long a) { return (float)a; }
double __floatundidf(unsigned long long a) { return (double)a; }
float __floatundisf(unsigned long long a) { return (float)a; }
