+++
title = "HTTP Handler Application Binary Interface (ABI)"
layout = "single"
+++

The HTTP handler ABI allows users to write portable HTTP server middleware in
a language that compiles to wasm. For example, a Go HTTP service could embed
routing middleware written in Zig.

The guest is the code compiled to wasm and the host is an HTTP server library
that accepts middleware plugins, such as [net/http][1] in Go. The host exports
functions for accessing HTTP messages under the module name "http_handler".

The overall process is the host calls the `handle_request` function exported by
the guest. This may use host functions it imports to inspect or manipulate
request or response properties. The guest decides whether to construct a
response, or return `next=1`, to proceed to the next handler on the host. If
so, the host calls `handle_response` to allow the guest to inspect or
manipulate the response.

An example is routing middleware. In this case, the guest constructs an 302
response instead of calling the next handler to redirect a path that moved to
a new host. If the path is relative, it could alternatively choose to forward
the request by resetting the path before calling the next handler.

## Conventions

This ABI is defined in English, with examples in [WebAssembly Text Format][2]
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

See [rationale]({{< ref "rationale.md" >}}) for context on design decisions.

## Lifecycle Functions

The HTTP handler guest is compiled and takes action on an incoming server
request. Its only requirement is to export `memory` and two functions:

* `handle_request`: called by the host on each request and returns `next=1` to
  continue to the next handler on the host.
* `handle_response`: caller by the host, regardless of error, when
  `handle_request` returned `next=1`.

For example, the guest logic might add a header in `handle_request` and proceed
to the next handler by returning `next=1`. Or it may decide to write its own
response and `next=0` to skip any next handlers on the host.

Note: All access to HTTP fields are via functions imported from the host.

### `ctx_next`

`ctx_next` is the result of `handle_request`. For compatability with
WebAssembly Core Specification 1.0, two i32 values are combined into a single
i64 in the following order:

* ctx: opaque 32-bits the guest defines and the host propagates to
  `handle_response`. A typical use is correlation of request state.
* next: one to proceed to the next handler on the host. zero to skip any next
  handler. Guests skip when they wrote a response or decided not to.

When the guest decides to proceed to the next handler, it can return
`ctx_next=1` which is the same as `next=1` without any request context. If it
wants the host to propagate request context, it shifts that into the upper
32-bits of `ctx_next` like below.

```webassembly
(func (export "handle_request") (result (; ctx_next ;) i64)
  ;; --snip--
  ;; return i64(reqCtx) << 32 | i64(1)
  (return
    (i64.or
      (i64.shl (i64.extend_i32_u (local.get $reqCtx)) (i64.const 32))
      (i64.const 1))))
```

Here are some examples of `ctx_next` values:

* `0<<32|0`  (0): don't proceed to the next handler.
* `0<<32|1`  (1): proceed to the next handler without context state.
* `16<<32|1` (68719476737): proceed to the next handler and call
  `handle_response` with 16.
* `16<<32|16` (68719476736): the value 16 is ignored because
  `handle_response` won't be called.

### `handle_request`

```webassembly
;; handle_request is the entrypoint defined and exported by the guest. The host
;; calls this for each request.
;;
;; The lower 32-bits of the `ctx_next` result ("next") can be zero or one:
;; one means proceed to the next handler on the host and zero means skip it.
;; The upper 32-bits are passed to "handle_response" as the `reqCtx` parameter.
;; See `ctx_next` for more information.
(func $handle (export "handle_request") (result (; ctx_next ;) i64)
  (return (i64.const 1)) ;; next=1 proceeds to the next handler
```

When `handle_request` returns zero, the guest wrote a response directly or
accepts the default empty HTTP 200 response. That said, a default
`handle_request` implementation should return `i64(1)` to proceed to the next
handler on the host.

### `handle_response`

```webassembly
;; handle_response is called after `handle_request` and any handlers defined on
;; the host.
;;
;; The `reqCtx` parameter is a possibly zero `ctx_next` "ctx" field the host
;; propagated from `handle_request`. This allows request correlation for guests
;; who need it.
;;
;; The `isError` parameter is one if there was a host error producing a
;; response. This allows guests to clean up any resources.
(import "http_handler" "handle_response" (func $next))
```

By default, whether the next handler on the host flushes the response prior to
returning is implementation-specific. If your handler needs to inspect or
manipulate a response inside `handle_response`, set `buffer-response` via
`enable_features`, described later.

## Memory

This specification relies completely on guest wasm to define how to manage
memory, and does not require WASI or any other guest imports.

"memory" is exported from the guest so that the host can read and write fields
like the URI. For example, string parameters are passed as a memory offset and
size (in bytes). Chunks of message bodies are also expressed as memory regions.

All functions that read fields from the host accept two `i32` parameters:
`buf` and `buf_limit`, representing the linear memory offset and maximum length
in bytes the host can write.

### `buf_limit`

```webassembly
;; buf_limit (i32) is the possibly zero maximum length of a result value to
;; write in bytes. If the actual value is larger than this, nothing is written
;; to memory.
```

This parameter supports the most common case of retrieving a header value by
name. However, there are some subtle use cases possible, particularly helpful
for WebAssembly performance:

* re-using a buffer for reading header or path values (`buf`).
* growing a buffer only when needed (retry with larger `buf_limit`).
* avoiding copying invalidly large header values (`buf_limit`).
* determining if a header exists without copying it (`buf_limit=0`).

In order for the guest to control memory usage, it can pass any `buf_limit` to
a function that reads a field. If it is sufficient, the result will be written
to `buf` and the result will be the length in bytes written. It is crucial to
understand that if the field is larger than the `buf_limit`, nothing is
written. This allows the guest to learn the length, by passing `buf_limit=0`.

For example, given the below function:

```webassembly
(import "http_handler" "get_path" (func $get_path
  (param $buf i32) (param $buf_limit i32)
  (result (; path_len ;) i32)))
```

A guest which uses a shared buffer can use its pre-allocated length as
`buf_limit`. If the result is over that limit it can attempt to extend that
limit (ex via `memory.grow`) and retry or trap/panic.

```webassembly
(func $handle (export "handle")
  ;; --snip--

  ;; path_len = get_path(buf, buf_limit)
  (local.set $path_len
    (call $get_path (global.get $buf) (local.get $buf_limit)))

  ;; if path_len > buf_limit { panic }
  (if (i32.gt_s (local.get $path_len) (local.get $buf_limit))
    (then unreachable)) ;; out of memory

  ;; Now, the path is at mem[buf:path_len]!
)
```

More routinely, guests are higher level languages that have garbage collection.
A guest can learn the length of the field by calling it with `buf_limit=0`. It
can then allocate a string of the exact length and retry.

Here's an example in Go:

```go
func GetPath() string {
    path_len := get_path(0, 0)
    if path_len == 0 {
        return ""
    }
    buf := make([]byte, path_len)
    ptr := iptr(unsafe.Pointer(&buf[0]))
    _ = getPath(ptr, path_len)
    return string(buf)
}
```

## Administrative Functions

### `get_config`

```webassembly
;; get_config writes configuration from the host to memory if it exists and
;; isn't larger than the `buf_limit`. The result is its length in bytes.
;;
;; Note: Configuration is guest-specific and not necessarily UTF-8 encoded.
;;
;; Note: A host who fails to get the configuration will trap (aka panic,
;; "unreachable" instruction).
(import "http_handler" "get_config" (func $get_config
  (param $buf i32) (param $buf_limit i32)
  (result (; len ;) i32)))
```

For example, if parameters buf=16 and buf_limit=128, and the host had
configuration "enabled=1\n", it would be written to memory like below, and 10
would be returned:

```
                                        len
                +---------------------------------------------+
                |                                             |
[]byte{ 0..15, 'e', 'n', 'a', 'b', 'l', 'e', 'd', '=', '1', '\n', ?, .. }
          buf --^
```

### `features`

HTTP handler ABI includes flags to help guests learn which features are
supported, and avoid enabling expensive features by default.

For example, trailers wasn't supported by fasthttp until [early 2022][2]. Also,
body buffering is an expensive feature not required by most middleware, so
shouldn't be enabled by default.

```webassembly
;; features (i32) is a bit flag of features a host may support. It is the
;; `features` parameter of `enable_features`. Here are the currently defined
;; flags:

;; feature_buffer_request buffers the HTTP request body when reading, so that
;; the next handler can also read it.
;;
;; Note: Buffering a request is done on the host and can use resources such as
;; memory. It also may reduce the features of the underlying request due to
;; implications of buffering or wrapping.
(global $feature_buffer_request  i32 (i32.const 1))

;; feature_buffer_response buffers the HTTP response produced by the next
;; handler defined on the host instead of sending it immediately.
;;
;; This allows the `handle_response` to inspect and overwrite the HTTP status
;; code, response body or trailers. As the response is deferred, expect timing
;; differences when enabled.
;;
;; Note: Buffering a response is done on the host and can use resources such as
;; memory. It also may reduce the features of the underlying response due to
;; implications of buffering or wrapping.
(global $feature_buffer_response i32 (i32.const 2))

;; feature_trailers allows guests to act differently depending on if the host
;; supports HTTP trailing headers (trailers) or not.
(global $feature_trailers        i32 (i32.const 4))
```

### `enable_features`

```webassembly
;; enable_features tries to enable the given features and returns the entire
;; feature bitflag supported by the host.
(import "http_handler" "enable_features" (func $enable_features
  (param $enable_features i32)
  (result  (; features ;) i32)))
```

`enable_features` must be called prior to returning from `handle_request` to
have any affect, but may be called prior to `handle` to fail fast, for example
inside a start function. Doing so reduces overhead per-call and also allows the
guest to fail early on unsupported.

If called during `handle_request`, any new features are only enabled for the
scope of the current request. This allows fine-grained access to expensive
features such as buffering. For example, a guest could enable buffering only
for specific URIs.

### Handling unsupported features

Some guests may be able to work around lack of features on the host. For
example, a logging handler may be fine without trailers, while a gRPC handler
should err as it needs to access the gRPC status trailer. A guest that requires
a feature should `enable_features` during initialization, instead of
per-request, allowing it to panic if the result doesn't include what they need.

#### Trailers

Trailers is a feature flag because trailers are not well-supported. For
example, fasthttp did not support trailers until early 2022.

A host that doesn't support trailers must do the following:

* return 0 for this bit in the `enable_features` result.
* return no trailer names or values.
* panic/trap on any call to set a trailer value.

## Logging Functions

### `log_level`

```webassembly
;; log_level (i32) controls the volume of logging. The lower the number the
;; more detail is logged.
;;
;; Note: The most voluminous level, LogLevelDebug is -1 to prevent users from
;; accidentally defaulting to it.
(global $log_level_debug i32 (i32.const -1))
(global $log_level_info  i32 (i32.const  0))
(global $log_level_warn  i32 (i32.const  1))
(global $log_level_error i32 (i32.const  2))
(global $log_level_none  i32 (i32.const  3))
```

### `log`

```webassembly
;; log adds a UTF-8 encoded message to the host's logs at the given $level.
;;
;; Note: A host who fails to log a message should ignore it instead of a trap
;; (aka panic, "unreachable" instruction).
(import "http_handler" "log" (func $log
  (param $level (; log_level ;) i32)
  (param $message i32) (param $message_len i32)))
```

For example, if parameters are level=0, message=1, message_len=5, this function
would log the message "error" to INFO level.

```
               message_len
           +------------------+
           |                  |
[]byte{?, 'e', 'r', r', 'o', 'r', ?}
 message --^
```

### `log_enabled`

```webassembly
;; log_enabled returns 1 if the $level is enabled. This value may be cached
;; at request granularity.
(import "http_handler" "log_enabled" (func $log_enabled
  (param $level i32)
  (result (; 0 or enabled(1) ;) i32)))
```

## Header Functions

The HTTP Handler ABI defines common functions for HTTP headers, regardless of
whether they are request or response, or trailing.

Here are the most important details about header functions.

* The header target is indicated by a `header_kind` enum. Ex `request` is 0.
* Functions that return multiple results write NUL-terminated value sequences
  to memory and returns the count and total length in bytes (`count_len`).
* To use trailing headers (trailers), you must enable `feature_trailers`.

Note: Multiple results are NUL-terminated sequences, not NUL-delimited. e.g.
"foo\00bar\00" not "foo\00bar".

### `header_kind`

```webassembly
;; header_kind (i32) is the first parameter to functions like `remove_header`.
;;
;; trailer kinds require enabling the feature `trailers`. Usage otherwise will
;; result in empty get or a trap (aka panic, "unreachable" instruction) on set.
(global $header_kind_request           i32 (i32.const 0))
(global $header_kind_response          i32 (i32.const 1))
(global $header_kind_request_trailers  i32 (i32.const 2))
(global $header_kind_response_trailers i32 (i32.const 3))
```

### `count_len`

```webassembly
;; count_len (i64) describes a possible empty sequence of NUL-terminated
;; strings. For compatability with WebAssembly Core Specification 1.0, two i32
;; values are combined into a single i64 in the following order:
;;
;; * count: zero if the sequence is empty, or the count of strings.
;; * len: possibly zero length of the sequence, including NUL-terminators.
;;
;; If the count_len is zero, the sequence is empty. Otherwise, count is the
;; upper 32 bits and len is the lower 32 bits.
```

Here are some examples of encoded `count_len` values:

* "": 0<<32|0 or simply zero.
* "Accept\0": 1<<32|7
* "Content-Type\0Content_length\0": 2<<32|28

For those unfamiliar with splitting a 64-bit number into two, here is how to do
it in WebAssembly's Text Format (`%.wat`) and Go:

* count: upper 32 bits
  * wat: `(i32.wrap_i64 (i64.shr_u (local.get $count_len) (i64.const 32)))`
  * Go: `i32(countLen >> 32)`
* len: lower 32 bits
  * wat: `(i32.wrap_i64 (local.get $count_len))`
  * Go: `i32(countLen)`

### `get_header_names`

```webassembly
;; get_header_names writes all header names, in lowercase, NUL-terminated, to
;; memory if the encoded length isn't larger than `buf_limit`. `count_len` is
;; returned regardless of whether memory was written.
;;
;; Note: A host who fails to get header names will trap (aka panic,
;; "unreachable" instruction).
(import "http_handler" "get_header_names" (func $get_header_names
  (param $kind i32)
  (param  $buf i32) (param $buf_limit i32)
  (result (; count << 32| len ;) i64)))
```

#### Single header example

For example, if only the "Date" header exists and the `buf_limit` parameter was
4, nothing would be written to memory. The caller would decide whether to retry
the request with a higher limit.

If parameters buf=16 and buf_limit=128, the result would be `1<<32|5` and
"Date" would be written to memory followed by a NUL character (0).

```
            i32(1<<32|5) == 4294967296 + 5
                +------------------+
                |                  |
[]byte{ 0..15, 'D', 'a', 't', 'e', 0, ?, .. }
          buf --^
```

#### Multiple headers example

For example, if two headers exist "Date" and "Etag", and the `buf_limit`
parameter was 9, nothing would be written to memory. The caller would decide
whether to retry the request with a higher limit.

If parameters buf=16 and buf_limit=128, the result would be `1<<32|8` and
"Date" and "Etag" will be written with NUL terminators (0) like below:

```
                      i32(1<<32|8) == 4294967296 + 10
                +-----------------------------------------+
                |                                         |
[]byte{ 0..15, 'D', 'a', 't', 'e', 0, 'E', 't', 'a', 'g', 0, ?, .. }
          buf --^
```

### `get_header_values`

```webassembly
;; get_header_values writes all values of the given name, NUL-terminated, to
;; memory if the encoded length isn't larger than `buf_limit`. `count_len` is
;; returned regardless of whether memory was written. The name must be treated
;; case-insensitive.
;;
;; Note: A host who fails to get header values will trap (aka panic,
;; "unreachable" instruction).
(import "http_handler" "get_header_values" (func $get_header_values
  (param $kind i32)
  (param $name i32) (param  $name_len i32)
  (param  $buf i32) (param $buf_limit i32)
  (result (; count << 32| len ;) i64)))
```

#### Single value example

For example, if parameters kind=response, name=1 and name_len=4, this function
would read the header name "ETag".

```
               name_len
           +--------------+
           |              |
[]byte{?, 'E', 'T', 'a', 'g', ?}
    name --^
```

If there was no `ETag` header, the result would be i64(0) and the user doesn't
need to read memory.

If the `buf_limit` parameter was 7, nothing would be written to memory. The
caller would decide whether to retry the request with a higher limit.

If parameters buf=16 and buf_limit=128, and there was a value "01234567", the
result would be `1<<32|9` and the value written like so:

```
                     i32(1<<32|9) == 4294967296 + 9
                +--------------------------------------+
                |                                      |
[]byte{ 0..15, '0', '1', '2', '3', '4', '5', '6', '7', 0, ?, .. }
          buf --^
```

#### Multiple value example

For example, if parameters kind=response, name=1 and name_len=10, this function
would read the header name "Set-Cookie".

```
                              name_len
           +--------------------------------------------+
           |                                            |
[]byte{?, 'S', 'e', 't', '-', 'C', 'o', 'o', 'k', 'i', 'e', ?}
    name --^
```

If there was no `Set-Cookie` header, the result would be i64(0) and the user
doesn't need to read memory.

If the `buf_limit` parameter was 7, nothing would be written to memory. The
caller would decide whether to retry the request with a higher limit.

If parameters buf=16 and buf_limit=128, and there were two values: "a=b" and
"c=d", the result would be `1<<32|8` and the value written like so:

```
                  i32(1<<32|8) == 4294967296 + 8
                +-------------------------------+
                |                               |
[]byte{ 0..15, 'a', '=', 'b', 0, 'c', '=', 'd', 0, ?, .. }
          buf --^
```

### `set_header_value`

```webassembly
;; set_header_value overwrites all values of the given header name with the
;; input.
;;
;; Note: A host who fails to set the header will trap (aka panic,
;; "unreachable" instruction).
(import "http_handler" "set_header_value" (func $set_header_value
  (param  $kind i32)
  (param  $name i32) (param $name_len i32)
  (param $value i32) (param $value_len i32)))
```

For example, if parameters are kind=response, name=1, name_len=4, value=8,
value_len=1, this function would set the response header "ETag: 1".

```
               name_len             value_len
           +--------------+             +
           |              |             |
[]byte{?, 'E', 'T', 'a', 'g', ?, ?, ?, '1', ?}
    name --^                            ^
                                value --+
```

### `add_header_value`

```webassembly
;; add_header_value adds a single value for the given header name.
;;
;; Note: A host who fails to add the header will trap (aka panic,
;; "unreachable" instruction).
(import "http_handler" "add_header_value" (func $add_header_value
  (param  $kind i32)
  (param  $name i32) (param $name_len i32)
  (param $value i32) (param $value_len i32)))
```

For example, if parameters kind=response, name=1, name_len=10, value=11 and
value_len=3, this function add a header field "Set-Cookie: c=d".

```
                              name_len                           value_len
           +--------------------------------------------+       +---------+
           |                                            |       |         |
[]byte{?, 'S', 'e', 't', '-', 'C', 'o', 'o', 'k', 'i', 'e', ?, 'a', '=', 'b', ?}
    name --^                                            value --^
```

### `remove_header`

```webassembly
;; remove_header removes all values for a header with the given name.
;;
;; Note: A host who fails to remove the header will trap (aka panic,
;; "unreachable" instruction).
(import "http_handler" "remove_header" (func $set_header_value
  (param  $kind i32)
  (param  $name i32) (param $name_len i32)
  (param $value i32) (param $value_len i32)))
```

## Body Functions

The HTTP Handler ABI defines common functions for HTTP bodies, regardless of
whether they are request or response.

Here are the most important details about body functions.

* Reads and writes are stateful and affect the stream.
* `feature_buffer_request` or `feature_buffer_response` may be required,
  depending on the logic compiled to the guest wasm.

### `body_kind`

```webassembly
;; body_kind (i32) is the first parameter to body functions like `write_body`.
(global $body_kind_request  i32 (i32.const 0))
(global $body_kind_response i32 (i32.const 1))
```

### `eof_len`

```webassembly
;; eof_len (i64) is the result of `read_body` which allows callers to know if
;; the bytes returned are the end of the stream. For compatability with
;; WebAssembly Core Specification 1.0, two i32 values are combined into a
;; single i64 in the following order:
;;
;;   - eof: the body is exhausted.
;;   - len: possibly zero length of bytes read from the body.
;;
;; Note: `EOF` is not an error, so process `len` bytes returned regardless.
```

Here are some examples:

* `1<<32|0 (4294967296)`: EOF and no bytes were read
* `0<<32|16 (16)`: 16 bytes were read and there may be more available.

For those unfamiliar with splitting a 64-bit number into two, here is how to do
it in WebAssembly's Text Format (`%.wat`) and Go:

* eof: upper 32 bits
  * wat: `(i32.wrap_i64 (i64.shr_u (local.get $count_len) (i64.const 32)))`
  * Go: `i32(countLen >> 32)`
* len: lower 32 bits
  * wat: `(i32.wrap_i64 (local.get $count_len))`
  * Go: `i32(countLen)`

### `read_body`

```webassembly
;; read_body reads up to `buf_limit` bytes remaining in the body into memory at
;; offset `buf`. A zero `buf_limit` will panic.
;;
;; The result is `eof_len`, indicating the count of bytes read and whether
;; there may be more available. Callers do not have to exhaust the stream until
;; `EOF`.
;;
;; Unlike `get_XXX` functions, this function is stateful, so repeated calls
;; reads what's remaining in the stream, as opposed to starting from zero.
;;
;; Note: A host who fails to read the body will trap (aka panic, "unreachable"
;; instruction).
(import "http_handler" "read_body" (func $read_body
  (param $kind i32)
  (param  $buf i32) (param $buf_len i32)
  (result (; 0 or EOF(1) << 32 | len ;) i64)))
```

Here are some `body_kind` specific notes about `read_body`:

* `feature_buffer_request` is required to invoke `read_body` without consuming
  the request body. To enable it, call `enable_features` before returning from
  `handle_request`. Otherwise, the next handler may panic attempting to read
  the request body because it was already read.
* `feature_buffer_response` is required to read the response body produced by
  the next handler defined on the host inside `handle_response`. To enable it,
  call `enable_features` beforehand. Otherwise, the gues tmay read EOF because
  the downstream handler already consumed it.

### `write_body`

```webassembly
;; write_body reads `body_len` bytes at memory offset `body` and writes them to
;; the pending body.
;;
;; Unlike `set_XXX` functions, this function is stateful, so repeated calls
;; write to the current stream.
;;
;; Note: A host who fails to write the body will trap (aka panic, "unreachable"
;; instruction).
(import "http_handler" "write_body" (func $write_body
  (param $kind i32)
  (param $body i32) (param $body_len i32)))
```

Here are some `body_kind` specific notes about `write_body`:

* The first call to `write_body` in `handle_request` overwrites any request body.
* The first call to `write_body` in `handle_request` or `handle_response`
  overwrites any response body.

## Request Only Functions

Functions such as `get_header_names` apply to both request and response
messages. Functions in this section only apply to an HTTP request.

### `get_method`

```webassembly
;; get_method writes the method to memory if it isn't larger than `buf_limit`,
;; e.g. "GET". The result is its length in bytes.
;;
;; Note: A host who fails to get the method will trap (aka panic, "unreachable"
;; instruction).
(import "http_handler" "get_method" (func $get_method
  (param $buf i32) (param $buf_limit i32)
  (result (; len ;) i32)))
```

For example, if parameters buf=16 and buf_limit=128, and the request
line was "GET /foo?bar HTTP/1.1", "GET" would be written to memory like below,
and the `len` would be three.

```
                    len
                +---------+
                |         |
[]byte{ 0..15, 'G', 'E', 'T', ?, .. }
          buf --^
```

### `set_method`

```webassembly
;; set_method overwrites the method with one read from memory, e.g. "POST".
;;
;; Note: A host who fails to set the method will trap (aka panic, "unreachable"
;; instruction).
(import "http_handler" "set_method" (func $set_method
  (param $method i32) (param $method_len i32)))
```

For example, if parameters are method=8, method_len=4, this function would set the
method to "POST".

```
              method_len
           +--------------+
           |              |
[]byte{?, 'P', 'O', 'S', 'T', ?}
  method --^
```

### `get_uri`

```webassembly
;; get_uri writes the URI to memory if it isn't larger than `buf_limit`, e.g.
;; "/v1.0/hi?name=panda". The result is its length in bytes.
;;
;; Note: The host should return "/" instead of empty for a request with no URI.
;;
;; Note: The URI may include query parameters. It will always write the URI encoded
;; to ASCII (both path and query parameters e.g. "/v1.0/hi?name=kung+fu+panda"). See
;; https://datatracker.ietf.org/doc/html/rfc3986#section-2 for more references.
;;
;; Note: A host who fails to get the URI will trap (aka panic, "unreachable"
;; instruction).
(import "http_handler" "get_uri" (func $get_uri
  (param $buf i32) (param $buf_limit i32)
  (result (; len ;) i32)))
```

For example, if parameters buf=16 and buf_limit=128, and the request
line was "GET /foo?bar HTTP/1.1", "/foo?bar" would be written to memory like
below, and the `len` of the URI would be returned:

```
                                 len
                +----------------------------------+
                |                                  |
[]byte{ 0..15, '/', 'f', 'o', 'o', '?', 'b', 'a', 'r', ?, .. }
          buf --^
```

### `set_uri`

```webassembly
;; set_uri overwrites the URI with one read from memory, e.g.
;; "/v1.0/hi?name=panda".
;;
;; Note: The URI may include query parameters. The guest MUST pass
;; the URI encoded as the host will ALWAYS expect the URI as encoded
;; and passing it unencoded could lead to unexpected behaviours.
;;
;; Note: A host who fails to set the URI will trap (aka panic, "unreachable"
;; instruction).
(import "http_handler" "set_uri" (func $set_uri
  (param $uri i32) (param $uri_len i32)))
```

For example, if parameters are uri=8, uri_len=2, this function would set the
URI to "/a". If any query parameters existed before, they are removed.

```
           uri_len
           +----+
           |    |
[]byte{?, '/', 'a', ?}
     uri --^
```

### `get_protocol_version`

```webassembly
;; writes the protocol version to memory if it isn't larger than `buf_limit`.
;; The result is its length in bytes.
;;
;; The most common protocol versions are "HTTP/1.1" and "HTTP/2.0".
;;
;; Note: A host who fails to get the protocol version will trap (aka panic,
;; "unreachable" instruction).
(import "http_handler" "get_protocol_version" (func $get_protocol_version
  (param $buf i32) (param $buf_limit i32)
  (result (; len ;) i32)))
```

For example, if parameters buf=16 and buf_limit=128, and the request
line was "GET /foo?bar HTTP/1.1", "HTTP/1.1" would be written to memory like
below, and the `len` would be eight.

```
                                len
                +----------------------------------+
                |                                  |
[]byte{ 0..15, 'H', 'T', 'T', 'P', '/', '1', '.', '1', ?, .. }
          buf --^
```

### `get_source_addr`

```webassembly
;; get_source_addr writes the client source addr as a string to memory if it isn't larger than `buf_limit`,
;; e.g. "1.1.1.1:12345" or "[fe80::101e:2bdf:8bfb:b97e]:12345". The result is its length in bytes. It supports both IPv4 and IPv6.
;;
;; Note: A host who fails to get the remote address will trap (aka panic, "unreachable"
;; instruction).
(import "http_handler" "get_source_addr" (func $get_source_addr
  (param $buf i32) (param $buf_limit i32)
  (result (; len ;) i32)))
```

For example, if parameters buf=16 and buf_limit=128, and the source address
`1.2.3.4:12345` would be written to memory like below,
and the `len` would be 13.

```
                    len
                +---------+
                |         |
[]byte{ 0..15, '1', '.', '2', '.', '3', .. }
          buf --^
```

## Response Only Functions

Functions such as `get_header_names` apply to both request and response
messages. Functions in this section only apply to an HTTP response.

### `get_status_code`

```webassembly
;; get_status_code returns the status code produced by the next handler defined
;; on the host, e.g. 200.
;;
;; Note: A host who fails to get the status code will trap (aka panic,
;; "unreachable" instruction).
(import "http_handler" "get_status_code" (func $get_status_code
  (result (; len ;) i32)))
```

For example, if the response line was "HTTP/1.1 200 OK", 200 would be returned.
Calling `get_status_code` before `handle_response` may panic.

### `set_status_code`

```webassembly
;; set_status_code overwrites the status code produced by the next handler defined
;; on the host, e.g. 200. To call this in `handle_response` requires
;;`feature_buffer_response`.
;;
;; Note: A host who fails to set the status code will trap (aka panic,
;; "unreachable" instruction).
(import "http_handler" "set_status_code" (func $set_status_code
  (param $status_code i32)))
```

The default status code is 200, so guests do not have to call this if only to
set that value.

A guest who needs to overwrite the status code assigned by the next handler
defined on the host must enable `features_buffer_response` beforehand, via
`enable_features`.

[1]: https://pkg.go.dev/net/http
[2]: https://www.w3.org/TR/wasm-core-1/#text-format%E2%91%A0
