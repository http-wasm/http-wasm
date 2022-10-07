# http-wasm-abi

[http-wasm][1] is HTTP server middleware implemented in [WebAssembly][2]. This
repository contains the Abstract Binary Interface (ABI), that defines how
hosts and guests can communicate compatability.

## Application Binary Interface (ABI)

The host side of the ABI is defined in WebAssembly Interface Types (wit),
for consistency with WASI, though [code generation][3] is not required for
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
[wit-bindgen][3] converts the case format of field names to lower_snake.

### Types

This specification only uses numeric types, defined in WebAssembly Core
Specification 1.0. For example, a string is passed as two `u32` parameters
corresponding to its segment in linear memory.

## Handler ABI

The [handler ABI](./http-handler.wit.md) defines the functions that the host makes
available to middleware. Frameworks adding support for http-handler middleware
must export the functions defined in the ABI to guest Wasm binaries for them
to function. Meanwhile, guests must minimally export memory as "memory".

[1]: https://github.com/http-wasm
[2]: https://webassembly.org/
[3]: https://github.com/bytecodealliance/wit-bindgen