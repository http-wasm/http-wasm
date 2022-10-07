# Types

## <a href="#buf_limit" name="buf_limit"></a> `buf-limit`: `u32`

  The possibly zero maximum length of a result value to write in bytes.
  If the actual value is larger than this, nothing is written to memory.
  A function that accepts this parameter returns `maybe-len`.

Size: 4, Alignment: 4

## <a href="#maybe_len" name="maybe_len"></a> `maybe-len`: `u64`

  maybe-len expresses a possibly nil length in bytes. To retain signature
  compatability with WebAssembly Core Specification 1.0, two u32 values are
  represented as a single u64 in the following order:
  
  - ok: zero if the value does not exist and one if it does.
  - len: possibly zero length in bytes of the value.
  
  If the result is zero, there is no value. Otherwise, the lower 32-bits are
  `len`. For example, in WebAssembly `i32.wrap_i64` unpacks the lower 32-bits
  as would casting in most languages (ex `uint32(maybe-len)` in Go).

Size: 8, Alignment: 8

# Functions

----

#### <a href="#log" name="log"></a> `log` 

  logs a message to the host's logs.
  
  Note: A host who fails to log the message will trap (aka panic,
  "unreachable" instruction).
##### Params

- <a href="#log.message" name="log.message"></a> `message`: `u32`
- <a href="#log.message_len" name="log.message_len"></a> `message-len`: `u32`

----

#### <a href="#get_request_header" name="get_request_header"></a> `get-request-header` 

  writes a header value to memory if it exists and isn't larger than
  `buf-limit`. The result is `1<<32|len`, where `len` is the bytes written,
  or zero if the header doesn't exist.
  
  Note: A host who fails to get the request header will trap (aka panic,
  "unreachable" instruction).
##### Params

- <a href="#get_request_header.name" name="get_request_header.name"></a> `name`: `u32`
- <a href="#get_request_header.name_len" name="get_request_header.name_len"></a> `name-len`: `u32`
- <a href="#get_request_header.buf" name="get_request_header.buf"></a> `buf`: `u32`
- <a href="#get_request_header.buf_limit" name="get_request_header.buf_limit"></a> `buf-limit`: [`buf-limit`](#buf_limit)
##### Results

- [`maybe-len`](#maybe_len)

