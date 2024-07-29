## Code shared between the HTTP/1.1 and HTTP/2 protocols

import std/[net, options, strutils]

type
  Header* = object
    key*, value*: string

  Headers* = seq[Header]

  HttpEmptyResponse* = object of CatchableError

  HttpResponse* = ref object
    raw*: string ## The raw response string

    httpVersion*: string ## The HTTP version the server responded with (eg. "1.1")
    code*: uint32 ## The HTTP status code the server responded with (eg. "200")
    headers*: Headers ## Response headers
    content*: string
      ## The response body, check the `Content-Type` header to find out what it is (HTML, JSON, XML, JPEG, etc.)

proc getHeader*(
    resp: HttpResponse, key: string, caseSensitive: bool = true
): Option[Header] {.inline, noSideEffect.} =
  case caseSensitive
  of true:
    for header in resp.headers:
      if header.key == key:
        return some(header)
  of false:
    for header in resp.headers:
      if header.key.toLowerAscii() == key.toLowerAscii():
        return some(header)

proc getInt*(
    header: Header
): int {.inline, gcsafe, noSideEffect, raises: [ValueError].} =
  header.value.parseInt()

proc getStr*(header: Header): string {.inline, gcsafe, noSideEffect.} =
  header.value

proc header*(key, val: string): Header {.inline, noSideEffect.} =
  Header(key: key, value: val)
