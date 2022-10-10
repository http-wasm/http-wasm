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

### Memory Allocation

This specification relies completely on guest wasm to define how to manage
memory, and does not require WASI or any other guest imports.

All functions that read fields from the host accept two `u32` parameters:
`buf` and `buf-limit`, representing the linear memory offset and maximum length
in bytes the host can write.

In order for the guest to control memory usage, it can pass any `buf-limit` to
a function that reads a field. If it is sufficient, the result will be written
to `buf` and the result will the length in bytes written.

For example, given the below function:
```webassembly
(import "http-handler" "get_path" (func $get_path
  (param $buf i32) (param $buf_limit i32)
  (result (; path_len ;) i32)))
```

A guest which uses a shared buffer can use its pre-allocated length as
`buf_limit`. If the result is over that limit it can attempt to extend that
limit (ex via `memory.grow`) and retry or trap/panic.

A guest with a memory allocator can learn the length of the field by calling it
with `buf_limit=0`. It can then allocate a string of the result length and
retry. This is typical in garbage collected languages.

Ex.
```go
func GetPath() string {
    path_len := get_path(0, 0)
    if path_len == 0 {
		return ""
    }
    buf := make([]byte, path_len)
    ptr := uintptr(unsafe.Pointer(&buf[0]))
    _ = getPath(ptr, path_len)
    return string(buf)
}
```

[1]: https://github.com/http-wasm
[2]: https://webassembly.org/
[3]: http-handler/http-handler.wit.md
[4]: https://github.com/bytecodealliance/wit-bindgen
