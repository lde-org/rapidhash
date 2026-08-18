local build = require("lde-build")

local out = assert(build.outDir, "outDir not set")

local commit = "e04c9f35fa5a11c8c11de0f7cc1bdad38978d429"
local header = build:fetch("https://raw.githubusercontent.com/Nicoshev/rapidhash/" .. commit .. "/rapidhash.h")
build:write("rapidhash.h", header)

local args
if jit.os == "Windows" then
	args = {
		"-shared", "-O2",
		"-I", out,
		"-o", out .. "/rapidhash_core.dll",
		out .. "/rapidhash_core.c",
	}
elseif jit.os == "OSX" then
	args = {
		"-dynamiclib", "-O2",
		"-I", out,
		"-o", out .. "/rapidhash_core.dylib",
		out .. "/rapidhash_core.c",
	}
else
	args = {
		"-shared", "-fPIC", "-O2",
		"-I", out,
		"-o", out .. "/rapidhash_core.so",
		out .. "/rapidhash_core.c",
	}
end

build:cc(args)
