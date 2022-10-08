# http-wasm-abi

[http-wasm][1] defines HTTP functions implemented in [WebAssembly][2]. This
repository contains Abstract Binary Interface (ABI) defining how hosts and
guests communicate compatability. These ABI are specified in WebAssembly
Interface Types (wit).

## http-handler

The [http-handler ABI][3] allows users to write portable HTTP server middleware
in a language that compiles to wasm. For example, a Go HTTP service could embed
routing middleware written in Zig.

## Conventions

The host side of the ABI is defined in WebAssembly Interface Types (wit),
for consistency with WASI, though [code generation][4] is not required for
reasons including this org provides host and guest bindings.

Conversion manually is direct as we only use numeric types in our definition.
For example, given the following function defined in "http-handler.wit.md":
```
log: func(
    message: u32,
    message-len: u32,
) -> ()
```

In WebAssembly Text Format (wat), the corresponding import would look like
this:
```webassembly
(func $log (import "http-handler" "log")
  (param $message i32) (param $message_len i32))
```

Note: While the import module is exactly the same case format as the file name,
[wit-bindgen][4] converts the case format of field names to lower_snake.

### Types

This specification only uses numeric types, defined in WebAssembly Core
Specification 1.0. For example, a string is passed as two `u32` parameters
corresponding to its segment in linear memory.

[1]: https://github.com/http-wasm
[2]: https://webassembly.org/
[3]: http-handler/http-handler.wit.md
[4]: https://github.com/bytecodealliance/wit-bindgen
