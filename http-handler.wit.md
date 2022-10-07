# HTTP handler ABI

The "http-handler" ABI defines the functions that the host makes available to
middleware. Frameworks adding support for http-handler middleware must export
the functions defined in the ABI to guest Wasm binaries for them to function.
Meanwhile, guests must minimally export memory as "memory". Further details are
described below.

## Types

### `buf-limit`

```wit
/// The possibly zero maximum length of a result value to write in bytes.
/// If the actual value is larger than this, nothing is written to memory.
/// A function that accepts this parameter returns `maybe-len`.
type buf-limit = u32
```

This parameter supports the most common case of retrieving a header value by
name. However, there are some subtle use cases possible, particularly helpful
for WebAssembly performance:

- re-using a buffer for multiple header reads (`buf`).
- growing a buffer only when needed (retry with larger `buf-limit`).
- avoiding copying invalidly large header values (`buf-limit`).
- determining if a header exists without copying it (`buf-limit=0`).

### `maybe-len`

```wit
/// maybe-len expresses a possibly nil length in bytes. To retain signature
/// compatability with WebAssembly Core Specification 1.0, two u32 values are
/// represented as a single u64 in the following order:
///
///   - ok: zero if the value does not exist and one if it does.
///   - len: possibly zero length in bytes of the value.
///
/// If the result is zero, there is no value. Otherwise, the lower 32-bits are
/// `len`. For example, in WebAssembly `i32.wrap_i64` unpacks the lower 32-bits
/// as would casting in most languages (ex `uint32(maybe-len)` in Go).
type maybe-len = u64
```

For example, if a value exists and is "01234567", then `len=8`, so `maybe-len`
is `i64(1<<32 | 8)` or `i64(4294967304)`.

## Guest exports

The http-handler guest is wasm that takes action on an incoming server request.
For example, `handle` could add a header or perform an authorization check.

### `handle`

"handle" is the entrypoint guest export called by the host when processing a
request. Its signature is nullary, with neither parameters nor results.

`handle` must dispatch to either "next" or "send_response" possibly
manipulating HTTP properties before or after. A default guest should call
"next".

Note: A guest who fails to handle the request will trap (aka panic,
"unreachable" instruction).

### `memory`

"memory" is required for string parameters as they are passed as a memory
offset and size (in bytes). It is also used for message bodies, which are
parameterized the same way.

## Host Exports

Host exports are bound to HTTP server middleware, possibly called by the guest
during `handle`. Most commonly, host functions allow the guest to read or write
HTTP message properties in a portable way, regardless of the backend server
libraries or even host language.

### `log`

```wit
/// logs a message to the host's logs.
///
/// Note: A host who fails to log the message will trap (aka panic,
/// "unreachable" instruction).
log: func(
    /// The memory offset of the UTF-8 encoded message to log.
    message: u32,
    /// The possibly zero length of the message in bytes.
    message-len: u32,
) -> ()
```

For example, if parameters are message=1, message-len=5, this function would
log the message "error".
```
               message-len
           +------------------+
           |                  |
[]byte{?, 'e', 'r', r', 'o', 'r', ?}
 message --^
```

### `get-request-header`

```wit
/// writes a header value to memory if it exists and isn't larger than
/// `buf-limit`. The result is `1<<32|len`, where `len` is the bytes written,
/// or zero if the header doesn't exist.
///
/// Note: A host who fails to get the request header will trap (aka panic,
/// "unreachable" instruction).
get-request-header: func(
    /// The memory offset of the UTF-8 encoded header name, which the host
    /// looks up case insensitively. Ex. "Content-Length" or "content-length".
    name: u32,
    /// The length of the header name in bytes.
    name-len: u32,
    /// The memory offset of the UTF-8 encoded header value, if a value exists
    /// and is not larger than `buf-limit` bytes.
    buf: u32,
    /// The possibly zero maximum length of the header value to write in bytes.
    /// If the actual value is larger than this, nothing is written to memory.
    buf-limit: buf-limit,
) -> maybe-len
```

For example, if parameters name=1 and name_len=4, this function would read the
header name "ETag".

```
               name-len
           +--------------+
           |              |
[]byte{?, 'E', 'T', 'a', 'g', ?}
    name --^
```

If there was no `ETag` header, the result would be i64(0) and the user doesn't
need to read memory.

If the `buf-limit` parameter was 7, nothing would be written to memory. The
caller would decide whether to retry the request with a higher limit.

If parameters buf=16 and buf_limit=128, and there was a value "01234567", the
result would be `1<<32|8` and the value written like so:
```
                         u32(maybe-len) == 8
                +----------------------------------+
                |                                  |
[]byte{ 0..15, '0', '1', '2', '3', '4', '5', '6', '7', ?, .. }
          buf --^
```
