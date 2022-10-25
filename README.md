# http-wasm-abi

[http-wasm][1] defines HTTP functions implemented in [WebAssembly][2]. This
repository contains Abstract Binary Interface (ABI) defining how hosts and
guests communicate compatability. These ABI are specified in WebAssembly
Interface Types (wit).

## HTTP handler

The [HTTP Handler ABI][3] allows users to write portable HTTP server middleware
in a language that compiles to wasm. For example, a Go HTTP service could embed
routing middleware written in Zig.

## Conventions

This ABI is defined in English, with examples in [WebAssembly Text Format][4]
(`%.wat`). The latter helps reduce ambiguity, particularly on function
signatures. Let's take an example of a configuration function.

Here's the host function signature in WebAssembly Text Format (wat):
```webassembly
(import "http_handler" "get_config" (func $get_config
  (param $buf i32) (param $buf_limit i32)
  (result (; len ;) i32)))
```

Note, this specification only uses numeric types, defined in WebAssembly Core
Specification 1.0. For example, a string is passed as two `i32` parameters
corresponding to its segment in linear memory.

See [RATIONALE.md](RATIONALE.md) for context on design decisions.

[1]: https://github.com/http-wasm
[2]: https://webassembly.org/
[3]: http-handler/http-handler.md
[4]: https://www.w3.org/TR/wasm-core-1/#text-format%E2%91%A0
