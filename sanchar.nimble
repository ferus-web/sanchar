# Package

version       = "2.0.2"
author        = "xTrayambak"
description   = "ferus-sanchar's rewrite"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.0.0"
requires "punycode >= 0.1.0"

taskRequires "fmt", "nph >= 0.3.0"
taskRequires "test", "drchaos >= 0.1.9"

task fmt, "Format code":
  exec findExe("nph") & " src/"

task docgen, "Generate documentation":
  selfExec "doc --project --index:on --outdir:docs src/sanchar/http.nim"

task fuzzUrl, "Run LLVM's fuzzer against Sanchar's URL parser":
  selfExec "c --define:release --define:speed --cc:clang -r tests/fuzz/url001.nim"
