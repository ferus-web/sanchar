## A mostly compliant implementation of the HTTP/1.1 protocol
## This is not meant to be used directly, as it only implements the base of the HTTP protocol.

import std/[options, strutils, strformat, net, parseutils]
import ./shared
import ../../parse/url

const Terminators = {'\t', '\v', '\r', '\n', '\f'}

proc pad*(data: var string) {.inline, gcsafe.} =
  data &= "\r\n"

proc prepareRequestData*(url: URL, headers: Headers): string {.inline, noSideEffect.} =
  var base = fmt"GET /{url.path()} HTTP/1.1"
  pad base

  for header in headers:
    base &= header.key & ": " & header.value
    pad base

  pad base

  base

proc parseHttpVersion*(
    resp: string
): tuple[postVParsePos: uint64, version: string] {.noSideEffect.} =
  var
    final: string
    curr: char
    pos: uint64

  # Advance until a '/' is found
  while curr != '/' and pos < resp.len.uint64:
    curr = resp[pos]
    inc pos

  # Now, get the HTTP version code
  reset(curr)

  while curr notin Whitespace:
    curr = resp[pos]
    final &= curr
    inc pos

  inc pos
  (postVParsePos: pos, version: final)

proc parseHttpStatusCode*(
    pvpos: uint64, resp: string
): tuple[postSParsePos: uint64, status: uint32, blandStatus: string] {.noSideEffect.} =
  var
    curr: char
    statusRaw: string
    pos: uint64 = pvpos - 1

  while curr notin Whitespace:
    curr = resp[pos]

    if curr in {'0' .. '9'}:
      statusRaw &= curr

    inc pos

  result.status = statusRaw.parseUint().uint32
  inc pos

  while curr notin Whitespace:
    curr = resp[pos]
    statusRaw &= curr

    inc pos

  result.postSParsePos = pos
  result.blandStatus = statusRaw

proc parseHttpHeaders*(
    pspos: uint64, resp: string
): tuple[postHParsePos: uint64, headers: Headers] {.noSideEffect.} =
  var
    key, value: string
    keyDone: bool
    pos: uint64 = pspos
    curr: char
    headers: Headers

  while pos < resp.len.uint64:
    curr = resp[pos]
    if curr == ':':
      keyDone = true
      pos += 2
      continue

    if not keyDone:
      if curr != '\n':
        key &= curr
    else:
      if curr notin Terminators:
        value &= curr
      else:
        keyDone = false
        headers.add(header(key, value))
        key.reset()
        value.reset()

    inc pos

  (postHParsePos: pos, headers: headers)

proc parseResponse*(resp: string): HttpResponse {.noSideEffect.} =
  var httpResp = HttpResponse()

  httpResp.raw = resp
  let (postVParsePos, version) = parseHttpVersion(resp)

  httpResp.httpVersion = version

  let (postSParsePos, status, bland) = parseHttpStatusCode(postVParsePos, resp)

  httpResp.code = status

  let (postHParsePos, headers) = parseHttpHeaders(postSParsePos, resp)

  httpResp.headers = headers
  httpResp.content = resp[postHParsePos .. resp.len - 1]

  httpResp

proc fetchResponse*(socket: Socket): Option[tuple[headers: string, body: seq[string]]] =
  var
    full: string
    offset: uint

    chunks: seq[string]
    contentLength: uint
    chunked: bool

  # This part is mostly taken from juancarlospaco's faster-than-requests library
  # https://github.com/juancarlospaco/faster-than-requests/blob/master/faster_than_requests/faster_than_requests.nim

  while true:
    let line = socket.recvLine()
    full &= line & "\r\n"

    let lineLower = line.toLowerAscii()

    if line == "\r\n":
      break
    elif lineLower.startsWith("content-length:"):
      contentLength = parseUInt(line.split(' ')[1])
    elif lineLower.startsWith("transfer-encoding: chunked"):
      chunked = true

  if chunked:
    while true:
      var chunkLenStr: string

      while true:
        var readChar: char
        let readLen = socket.recv(readChar.addr, 1)
        assert readLen == 1

        chunkLenStr &= readChar
        if chunkLenStr.endsWith("\r\n"):
          break

      if chunkLenStr == "\r\n":
        break

      var chunkLen: int
      discard parseHex(chunkLenStr, chunkLen)

      if chunkLen < 1:
        break

      var chunk = newString(chunkLen)
      let readLen = socket.recv(chunk[0].addr, chunkLen)
      assert readLen == chunkLen

      chunks.add(chunk)

      var endStr = newString 2
      let readLen2 {.used.} = socket.recv(chunk[0].addr, contentLength.int)
  else:
    if contentLength < 1:
      return

    var chunk = newString(contentLength)
    let readLen {.used.} = socket.recv(chunk[0].addr, contentLength.int)
    chunks.add(chunk)

  if full.len > 0:
    return some((headers: full, body: chunks))

proc fetchBody*(socket: Socket, headersLength, contentLength: int): Option[string] =
  var
    body: string
    pos: int

  let length = contentLength - headersLength

  while pos < length:
    let c = socket.recv(1)
    body &= c

  echo body

  body.some()
