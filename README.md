# http-wasm-abi

[http-wasm][1] is HTTP server middleware implemented in [WebAssembly][1]. This
repository contains the Abstract Binary Interface (ABI), that defines how
hosts and guests can communicate compatability.

## Application Binary Interface (ABI)

The HTTP middleware ABI is currently being defined. Follow this repository for
updates.

### Common notes

- Parameters of type `string` expand to two parameters of type `i32`, the
  first being the pointer to the contents of the string and the second being 
  the number of bytes. *Note* that for unicode strings, the number of bytes is
  larger than the number of characters.

### Handler ABI

The [handler ABI](./http-handler.md) defines the functions that the host makes
available to middleware. Frameworks adding support for http-handler middleware
must export the functions defined in the ABI to guest Wasm binaries for them
to function. Meanwhile, guests must minimally export memory as "memory".

[1]: https://github.com/http-wasm
[2]: https://webassembly.org/
