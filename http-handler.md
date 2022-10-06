# Types
## <a href="#ptr" name="ptr"></a> `ptr`: `Pointer<u8>`
ptr is a linear memory byte offset.

Size: 4

Alignment: 4

## <a href="#size" name="size"></a> `size`: `u32`
size is a size in bytes to read or write from a memory offset.

Size: 4

Alignment: 4

# Modules
## <a href="#http-handler" name="http-handler"></a> http-handler
### Imports
#### Memory
### Functions

---

#### <a href="#log" name="log"></a> `log(message: ptr, message_len: size)`
FuncLog logs a message to the host's logs.

For example, if parameters are message=8, message_len=2, this function
would log the message "error".

```
              message_len
           +--------------+
           |              |
[]byte{?, 'e', 'r', 'o', 'r', ?}
 message --^
```

Note: A host who fails to log the message will trap (aka panic, "unreachable" instruction).

##### Params
- <a href="#log.message" name="log.message"></a> `message`: [`ptr`](#ptr)
The memory offset of the UTF-8 encoded message to log.

- <a href="#log.message_len" name="log.message_len"></a> `message_len`: [`size`](#size)
The possibly zero length of the message in bytes.

##### Results
