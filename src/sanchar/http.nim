## A HTTP client.
##
## .. code-block:: Nim
##  import sanchar/http
##
##  var client = httpClient()
##  client.addHeader("User-Agent", "Your/User/Agent")
##
##  let resp = client.get(parse("https://www.google.com"))
##  doAssert resp.code == 200

import std/[net, options, strutils, net]

import parse/[url], proto/http/[v1_1, v2, shared]

type
  SocketDefect* = object of Defect
    ## Any defect related to socket instantiation raises this.

  SSLNotLinkedDefect* = object of Defect
    ## Raised when a HTTPS URL is passed, but the code was not compiled with `-d:ssl`.

  HttpProtocolVersion* = enum
    ## The HTTP protocol version to use.
    http1_1
    http2

  HttpClient* = object ## The HTTP client object
    sock: Socket
    headers: seq[Header]

    when defined(ssl):
      secureSock: Socket

proc makeSocket*(ssl: bool = false): Socket {.inline, raises: [].} =
  ## This is just a convenience function used by the HTTP client to create sockets.
  ## It will never raise any exceptions. All errors are treated as unrecoverable defects/panics.
  var sock: Socket
  try:
    sock = newSocket(AF_INET, SOCK_STREAM)
  except OSError as exc:
    raise
      newException(SocketDefect, "Failed to create socket for HTTP client: " & exc.msg)

  if ssl:
    when defined(ssl):
      var ctx: SslContext

      try:
        ctx = newContext()
      except CatchableError as exc:
        raise newException(
          SocketDefect, "Failed to create SSL context for HTTP client: " & exc.msg
        )
      except Exception as exc:
        raise newException(
          SocketDefect, "Failed to create SSL context for HTTP client: " & exc.msg
        )

      try:
        ctx.wrapSocket(sock)
      except SslError as exc:
        raise
          newException(SocketDefect, "Failed to wrap socket in SSL context: " & exc.msg)
    else:
      raise newException(
        SSLNotLinkedDefect,
        "Attempt to create SSL socket without SSL support; compile with `-d:ssl` to fix this!",
      )

  sock

proc `=destroy`*(http: HttpClient) =
  if http.sock != nil:
    http.sock.close()

proc addHeader*(client: var HttpClient, key, val: string) {.inline.} =
  ## Add/set a header in the HTTP client.
  ## .. code-block:: Nim
  ##  import sanchar/http
  ##
  ##  var client = httpClient()
  ##  client.addHeader("Very-Useful-Header", "Yes")
  ##
  ## **See also:**
  ## - <addHeader(client: var HttpClient, header: Header)>_
  # If a header already exists, just modify its key, otherwise allocate a new header object.
  for i, header in client.headers:
    if header.key == key:
      client.headers[i].value = val
      return

  client.headers.add(header(key, val))

proc addHeader*(client: var HttpClient, header: Header) {.inline.} =
  ## Add/set a header in the HTTP client, except with a proper header.
  ## .. code-block:: Nim
  ##  var client = httpClient()
  ##  client.addHeader(header("Very-Useful-Header", "Yes"))
  ##
  ## **See also:**
  ## - <addHeader(client: var HttpClient, key, val: string)>_
  for i, pHeader in client.headers:
    if pHeader.key == header.key:
      client.headers[i] = header
      return

  client.headers.add(header)

proc addHeaders*(client: var HttpClient, headers: Headers) {.inline.} =
  ## Add/set multiple headers in the HTTP client.
  ##
  ## .. code-block:: Nim
  ##  import sanchar/[shared, http]
  ##
  ##  var client = httpClient()
  ##  client.addHeaders(
  ##    @[
  ##      header("User-Agent", "Very Cool User Agent") ,
  ##      "Is-Stupid".header("Yep")
  ##    ]
  ##  )
  for header in headers:
    for i, pHeader in client.headers:
      if pHeader.key == header.key:
        client.headers[i] = header
        return

    client.headers.add(header)

proc postResponse(client: var HttpClient, url: URL, response: HttpResponse) =
  ## This function is called after a HTTP request has succeeded.
  let connHeader = response.getHeader("Connection")

  if connHeader.isSome:
    let connection = connHeader.get()
    if connection.value == "close":
      case url.scheme
      of "http":
        client.sock.close()
      of "https":
        when defined(ssl):
          client.secureSock.close()

proc get*(
    client: var HttpClient,
    url: URL,
    headers: Headers = @[],
    proto: HttpProtocolVersion = http1_1,
): HttpResponse =
  ## Send a HTTP/GET request to a URL, and get a HTTP response.
  ##
  ## .. code-block:: Nim
  ##  import sanchar
  ##
  ##  var client = httpClient()
  ##
  ##  let resp = client.get(parse("https://example.com"))
  ##
  ##  echo resp.content
  client.addHeader("Host", url.hostname())

  var sock = client.sock

  if url.scheme == "https":
    when defined(ssl):
      sock = client.secureSock
    else:
      raise newException(
        SSLNotLinkedDefect,
        "Attempt to connect to a HTTPS domain without SSL support, compile with `-d:ssl` to fix this!",
      )

  sock.connect(url.hostname(), Port(url.port()))

  var payload: string

  case proto
  of http1_1:
    payload = v1_1.prepareRequestData(url, client.headers)
  else:
    discard

  sock.send(payload)

  var
    rsp: Option[tuple[headers: string, body: seq[string]]]
    body: Option[string]

  case proto
  of http1_1:
    rsp = v1_1.fetchResponse(sock)
  else:
    discard

  if not rsp.isSome:
    raise newException(HttpEmptyResponse, "Server responded with empty response!")

  let responseString = rsp.get().headers

  var response: HttpResponse

  case proto
  of http1_1:
    response = v1_1.parseResponse(responseString)
  else:
    discard

  response.content = rsp.get().body.join()

  client.postResponse(url, response)

  response

proc httpClient*(headers: Headers = @[]): HttpClient {.raises: [].} =
  ## Instantiate a HTTP client. Optionally, provide `seq[Header]` to set some headers by default.
  ##
  ## .. code-block:: Nim
  ##  import sanchar
  ##
  ##  var client = httpClient()
  var
    sock = makeSocket(ssl = false)
    client = HttpClient(sock: sock, headers: headers)

  when defined(ssl):
    client.secureSock = makeSocket(ssl = true)
  else:
    {.
      warning:
        "This program is being compiled without SSL support. HTTPS domains will not be reachable."
    .}

  client

export parse
