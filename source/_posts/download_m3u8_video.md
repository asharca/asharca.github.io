---
title: 如何爬取 m3u8 视频
date: 2025-05-07 14:48:59
updated:
category: [Tech]
tags: [m3u8, ffmpeg, python]
mermaid:
index_img:
---

在尝试抓取一个网站的视频时，发现它是用 m3u8 格式存储的，基于 AES128 加密，但是获取的密钥不是 16 byte，而是 33 byte，导致无法解密。

<!-- more -->

## 什么是 m3u8 ？和 hls 的关系？

HLS（HTTP Live Streaming）是 Apple 推出的一种 基于 HTTP 的流媒体传输协议。
它将音视频内容切割成一个个小的媒体片段（通常是 .ts 文件），并通过一个 播放列表文件（m3u8） 控制播放顺序。

.m3u8 是 HLS 播放列表文件的格式，本质是一个文本文件，内容是一些标签（如 #EXTINF、#EXT-X-KEY 等）和媒体片段的 URL 路径。

.m3u8 文件的格式如下：

```m3u8
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXT-X-KEY:METHOD=AES-128,URI="https://example.com/key.key",IV=0x00000000000000000000000000000001
#EXTINF:9.009,
segment1.ts
#EXTINF:9.009,
segment2.ts
#EXTINF:9.009,
segment3.ts
#EXT-X-ENDLIST
```

• #EXT-X-KEY 指定了加密方法和 key 地址
• #EXTINF 表示每个片段的时长
• segmentX.ts 是视频的实际数据片段

## 解析 m3u8 文件

当加密算法指定为 AES-128 时，key 的长度应该是 16 字节（128 位），如果是 URL，那么 URL 返回的内容也应该是 16 字节。
但是我访问 key 返回的内容是 33 字节：

![m3u8_key](../img/m3u8_key.png)

继续深入分析前端代码，全文搜索关键字，decode 之类的，发现一段 js 如下：

```js
function decode(data) {
  var bytes = new Uint8Array(data);
  var len = bytes.length;
  var inputPtr = decoderModule._malloc(len);
  decoderModule.HEAPU8.set(bytes, inputPtr);
  decoderModule._decrypt(inputPtr, len);
  var outputArray = new Uint8Array(
    decoderModule.HEAPU8.buffer,
    inputPtr,
    16
  );
  decoderModule._free(inputPtr);
  return outputArray;
}
```

decoderModule 是一个 WebAssembly 模块。
下载通过 `wasm2wat` 转换成的文本文件如下：

```wat
...
  (table (;0;) 1 1 funcref)
  (memory (;0;) 256 256)
  (global (;0;) (mut i32) (i32.const 5244960))
  (export "b" (memory 0))
  (export "c" (func 2))
  (export "d" (func 8))
  (export "e" (func 4))
  (export "f" (func 3))
  (export "g" (table 0))
  (export "h" (func 7))
  (export "i" (func 6))
  (export "j" (func 5))
...
```

暴露出几个方法，但是都是单个字母命名，不清楚每个函数的作用，无法直接调用。因为是 WebAssembly 模块，所以肯定有 js 声明文件，
继续搜索关键字，找到了前端如何调用这个方法的位置：

```js
...
var asm = createWasm();
var ___wasm_call_ctors = (Module["___wasm_call_ctors"] = function () {
  return (___wasm_call_ctors = Module["___wasm_call_ctors"] =
    Module["asm"]["c"]).apply(null, arguments);
});
var _decrypt = (Module["_decrypt"] = function () {
  return (_decrypt = Module["_decrypt"] = Module["asm"]["d"]).apply(
    null,
    arguments
  );
});
var _malloc = (Module["_malloc"] = function () {
  return (_malloc = Module["_malloc"] = Module["asm"]["e"]).apply(
    null,
    arguments
  );
});
var _free = (Module["_free"] = function () {
  return (_free = Module["_free"] = Module["asm"]["f"]).apply(
    null,
    arguments
  );
});
var stackSave = (Module["stackSave"] = function () {
  return (stackSave = Module["stackSave"] = Module["asm"]["h"]).apply(
    null,
    arguments
  );
});
var stackRestore = (Module["stackRestore"] = function () {
  return (stackRestore = Module["stackRestore"] =
    Module["asm"]["i"]).apply(null, arguments);
});
var stackAlloc = (Module["stackAlloc"] = function () {
  return (stackAlloc = Module["stackAlloc"] = Module["asm"]["j"]).apply(
    null,
    arguments
  );
});
...
```

知道每个函数的作用就可以用 python 把对每个 ts 分片进行解密了，具体解密代码如下：

```python
def decrypt_key(self, encrypted_key):
    """Decrypt encryption key using WASM module"""
    try:
        malloc = self.instance.exports.e
        decrypt = self.instance.exports.d
        free = self.instance.exports.f
        memory = self.instance.exports.b

        input_ptr = malloc(len(encrypted_key))
        mem_view = memory.uint8_view()

        for i, byte in enumerate(encrypted_key):
            mem_view[input_ptr + i] = byte

        decrypt(input_ptr, len(encrypted_key))

        decrypted_key = bytes(mem_view[input_ptr:input_ptr + 16])

        free(input_ptr)

        return decrypted_key
    except Exception as e:
        logger.error(f"Decryption failed: {e}")
        raise
```

对每个 ts 分片解密以后再利用 ffmpeg 拼接即可。
