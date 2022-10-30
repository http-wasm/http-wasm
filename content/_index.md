+++
title = "http-wasm: HTTP functions implemented in WebAssembly"
layout = "single"
+++

http-wasm defines HTTP functions implemented in [WebAssembly][1]. This
repository contains Application Binary Interface (ABI) defining how hosts and
guests communicate compatability. This site describes both the ABI currently
specified and known implementations of them.

## HTTP handler

The [HTTP Handler](http-handler) allows users to write portable HTTP server
middleware in a language that compiles to wasm. For example, a Go HTTP service
could embed routing middleware written in Zig.

[1]: https://webassembly.org/
