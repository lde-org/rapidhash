/*
 * rapidhash_core.c - FFI bridge for the reference rapidhash implementation.
 *
 * Compiled by build.lua into a shared library that src/init.lua loads via
 * LuaJIT FFI. LuaJIT strings are passed in-place (zero-copy) as `const void*`.
 */
#include "rapidhash.h"

uint64_t rapidhash_core_hash(const void *key, size_t len, uint64_t seed) {
	return rapidhash_withSeed(key, len, seed);
}
