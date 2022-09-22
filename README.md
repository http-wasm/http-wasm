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

The Wasm Middleware *guest* can be written in any language that supports the
ABI in use by the *host*. For example, the middleware could be programmed in C
(ex. [Rust][4]) or Go (ex. [TinyGo][5]).

While native middleware often require rebuilding the program from source, users
of Wasm middleware are free to swap out implementations decoupled from any
changes to the binary. WebAssembly is a sand-boxed architecture, so the host
process can safely run code defined externally.

## Application Binary Interface (ABI)

The HTTP middleware ABI is not yet defined, but will be after practice. Follow
this repository for updates.

[1]: https://webassembly.org/
[2]: https://wazero.io
[3]: https://v8.dev
[4]: https://rustwasm.github.io/docs/book
[5]: https://tinygo.org/docs/guides/webassembly/
