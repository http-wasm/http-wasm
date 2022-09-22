# http-wasm-abi

This repository holds the [WebAssembly][1] Abstract Binary Interface (ABI) for
HTTP middleware.

## Overview

WebAssembly has a virtual machine architecture where the *host* is the
embedding process and the *guest* is a program compiled into the WebAssembly
Binary Format, also known as Wasm. The Abstract Binary Interface (ABI) is the
contract between the *host* and the *guest*, primarily defining functions each
side can import.

Let's take an example of a program that embeds an HTTP processor. This processor
has a chain of middleware that allows it to customize or change requests and
responses. Middleware in Wasm can be included in this chain.

```goat
 .----------------------. 
|                        |
|  .------------------.  |
| | HTTP Processor     | |
|  '------+-----------'  | 
|         |  ^           |
|         v  |           |
|  .---------+--------.  |
| | Native Middleware  | |
|  '------+-----------'  | 
|         |  ^           |
|         v  |           |
|  .---------+--------.  |
| | Wasm Middleware    | |
| |                    | |
| | .-----.    .-----. | |
| || Host  |  | Guest || |
| ||       +->|       || |
| ||       |<-+       || |
| | '-----'    '-----' | |
|  '------+-----------'  | 
|         |  ^           |
|         v  |           |
|  .---------+--------.  |
| | Native Middleware  | |
|  '------------------'  | 
|                        |
 '----------------------' 
```

The Wasm Middleware *host* is written in native code, and compiled into the
application. For example, this code could use [wazero][2] as the WebAssembly
runtime, if the host was written in Go, or [V8][3], if C++.

The Wasm Middleware *guest* can be written in any language that can be compiled
to Wasm. For example, the middleware could be programmed in C
(ex. [Rust][4]) or Go (ex. [TinyGo][5]).

While native middleware often require rebuilding the program from source, users
of Wasm middleware are free to swap out implementations decoupled from any
changes to the binary. WebAssembly is a sand-boxed architecture, so the host
process can safely run code defined externally.

## Application Binary Interface (ABI)

The HTTP middleware ABI is currently being defined. Follow this repository for updates.

### Common notes

- Parameters of type `string` expand to two parameters of type `u32`, the first being
the pointer to the contents of the string and the second being the number of bytes.
Note that for unicode strings, the number of bytes is larger than the number of
characters.

### Host ABI

The [host ABI](./http-host.md) defines the functions that the host makes available to
middleware. Frameworks adding support for http-wasm middleware must export the
functions defined in the ABI to guest Wasm binaries for them to function.

[1]: https://webassembly.org/
[2]: https://wazero.io
[3]: https://v8.dev
[4]: https://rustwasm.github.io/docs/book
[5]: https://tinygo.org/docs/guides/webassembly/
