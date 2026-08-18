# rapidhash

LuaJIT bindings to the reference [rapidhash](https://github.com/Nicoshev/rapidhash)

## Usage

```
lde add rapidhash
```

```lua
local rapidhash = require("rapidhash")

rapidhash.hash("hello")              --> uint64 cdata
rapidhash.hash("hello", 42)          --> number seeds accepted
rapidhash.hash("hello", 0x2aULL)     --> cdata seeds accepted
rapidhash.hex("hello")               --> "2f4e5e5b9b8b8b8b" hex string
```

## Why not write it in LuaJIT?

LuaJIT does not support 128 bit integers natively. So performance is limited compared to a C implementation.

## Speed

Measured with `benchmarks/` on this machine (zero-copy FFI calls into the native core):

| input | rapidhash | fnv1a (Lua baseline) |
| ----- | --------- | -------------------- |
| 1 KB | ~28 GB/s | ~0.25 GB/s |
| lockfile (~15 KB) | ~32 GB/s | ~0.24 GB/s |
| 64 KB | ~31 GB/s | ~0.24 GB/s |
| 1 MB | ~27 GB/s | — |

~100× faster than the byte-at-a-time FNV-1a.
