+++
title = "HTTP Handler"
layout = "single"
+++

[WebAssembly][1] is a way to safely run code compiled in other languages.
Runtimes execute WebAssembly Modules (Wasm), which are most often binaries with
a `.wasm` extension.

WebAssembly has a virtual machine architecture where the *host* is the
embedding process and the *guest* is a program compiled into the WebAssembly
Binary Format, also known as Wasm. The Abstract Binary Interface (ABI) is the
contract between the *host* and the *guest*, primarily defining functions each
side can import.

Implementations of the [http-handler ABI](/http-handler-abi) allows you to
manipulate an incoming request or serve a response with custom logic compiled
to a Wasm binary. In other words, you can extend features of your HTTP server
binary with third-party code, without recompiling.

Let's take an example of a program that embeds an HTTP handler. This handler
has a chain of handler that allows it to customize or change requests and
responses. Handler in Wasm can be included in this chain.

```goat
 .----------------------. 
|                        |
|  .------------------.  |
| |   HTTP listener    | |
|  '------+-----------'  | 
|         |  ^           |
|         v  |           |
|  .---------+--------.  |
| |    http-handler    | |
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
| |    Next Handler    | |
|  '------------------'  | 
|                        |
 '----------------------' 
```

The http-handler *host* is written in native code, and compiled into the
application. Here are the currently supported hosts:

* [Go](https://github.com/http-wasm/http-wasm-host-go): e.g. for `net/http`
* [Node.js](https://github.com/http-wasm/http-wasm-host-js): e.g. for `express`

The http-handler *guest* can be written in any language that supports the
ABI in use by the *host*. Here are the currently supported guests:

* [TinyGo](https://github.com/http-wasm/http-wasm-guest-tinygo)

In fact, http-handler was written to be implemented in any guest language,
including by hand. To prove it, we implemented many examples, in WebAssembly's
[text format](https://github.com/http-wasm/http-wasm-host-go/tree/main/examples).

In summary, while native handler often require rebuilding the program from
source, users of http-handler are free to swap out implementations decoupled
from any changes to the binary. WebAssembly is a sand-boxed architecture, so
the host process can safely run code defined externally.

[1]: https://webassembly.org/
[2]: https://wazero.io
[3]: https://v8.dev
[4]: https://rustwasm.github.io/docs/book
[5]: https://tinygo.org/docs/guides/webassembly/
