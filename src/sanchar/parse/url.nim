## A mostly WhatWG compliant URL parser
## Parsing URLs
## ============
##
## This example creates a URL parser, and parses a string to make it a URL type.
##
## .. code-block:: Nim
##  import sanchar
##
##  var parser = newURLParser()
##  let url = parser.parse("https://google.com")
##
##  doAssert url.getScheme() == "https"
##  doAssert url.getHostname() == "google.com"
##  doAssert url.getTLD() == "com"

import std/[options, strutils, tables]
import punycode

const
  DEFAULT_PROTO_PORTS =
    {"ftp": 20'u, "http": 80'u, "https": 443'u, "gemini": 1965'u}.toTable
  ALLOWED_HOSTNAME_CHARS = {'a' .. 'z'} + {'0' .. '9'} + {'-', '.'}
  PUNYCODE_PREFIX = "xn--"

type
  ## An error that occured whilst initializing a URL, possibly due to bad arguments
  URLException* = object of Defect

  ## An error that occured whilst parsing a URL
  URLParseError* = object of CatchableError

  ## The current state of the URL parser
  URLParserState* = enum
    sInit
    parseScheme
    parseHostname
    parsePort
    parsePath
    parseFragment
    parseQuery
    sEnd
    limbo

  ## The URL parser itself
  URLParser* = object
    state: URLParserState

  BlobURL* = object
    kind*: string
    buffer*: seq[byte]

  ## The URL type, contains everything for a URL
  URL* = object
    # scheme     hostname                   path
    # ^^^^^   ^^^^^^^^^^^^^     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    # https://wikipedia.org:443/wiki/Nim_(programming_language)#Adoption
    #                       ^^^                                 ^^^^^^^^
    #                      port                                 fragment
    scheme: string ## The scheme of the URL.
    hostname: string ## The hostname of the URL.
    port: uint ## The port of the URL.
    portRaw: string ## The raw string representing the port of the URL.
    path: string ## The path of the URL.
    fragment: string ## The fragment of the URL.
    query: string ## The query of the URL.

    blob: Option[BlobURL]

    parsedScheme: bool
    parsedHostname: bool
    parsedPort: bool
    parsedPath: bool
    parsedFragment: bool

proc `scheme=`*(url: var URL, scheme: sink string) {.inline, gcsafe.} =
  url.scheme = move(scheme)

proc `hostname=`*(url: var URL, hostname: sink string) {.inline, gcsafe.} =
  url.hostname = move(hostname)

proc `port=`*(url: var URL, port: sink uint) {.inline, gcsafe.} =
  url.port = move(port)

proc `path=`*(url: var URL, path: sink string) {.inline, gcsafe.} =
  url.path = move(path)

proc `fragment=`*(url: var URL, fragment: sink string) {.inline, gcsafe.} =
  url.fragment = move(fragment)

proc `query=`*(url: var URL, query: sink string) {.inline, gcsafe.} =
  url.query = move(query)

proc `blobEntry=`*(url: var URL, blob: sink BlobURL) {.inline, gcsafe.} =
  url.blob = some(move(blob))

proc `=destroy`*(url: URL) =
  `=destroy`(url.scheme)
  `=destroy`(url.hostname)
  `=destroy`(url.portRaw)
  `=destroy`(url.path)
  `=destroy`(url.fragment)
  `=destroy`(url.query)

proc `=copy`*(src: var URL, dest: URL) =
  `=destroy`(src)
  wasMoved(src)

  src.scheme = dest.scheme
  src.hostname = dest.hostname
  src.port = dest.port
  src.portRaw = dest.portRaw
  src.path = dest.path
  src.fragment = dest.fragment
  src.query = dest.query

  src.parsedScheme = dest.parsedScheme
  src.parsedHostname = dest.parsedHostname
  src.parsedPort = dest.parsedPort
  src.parsedPath = dest.parsedPath
  src.parsedFragment = dest.parsedFragment

proc `$`*(url: URL): string {.noSideEffect.} =
  ## Turn the URL back into a string representation
  ## This can turn a URL back into string form
  ##
  ## .. code-block:: nim
  ##    import ferus_sanchar
  ##
  ##    let url = URL(
  ##      scheme: "https",
  ##      hostname: "google.com",
  ##      port: 443,
  ##      portRaw: "443",
  ##      path: "",
  ##      fragment: "",
  ##      query: ""
  ##    )
  ##
  ##    doAssert $url == "https://google.com/"
  result = url.scheme & "://" & url.hostname

  if url.portRaw.len > 0:
    result &= ':' & url.portRaw

  result &= '/' & url.path

  if url.fragment.len > 0:
    result &= '#' & url.fragment

  if url.query.len > 0:
    result &= '?' & url.query

func scheme*(url: URL): string {.inline.} =
  ## Get the scheme of a URL
  ##
  ## .. code-block:: Nim
  ##  import ferus_sanchar
  ##
  ##  let url = URL(
  ##    scheme: "https",
  ##    hostname: "google.com",
  ##    port: 443,
  ##    portRaw: "443",
  ##    path: "",
  ##    fragment: "",
  ##    query: ""
  ##  )
  ##
  ##  doAssert url.getScheme() == "https"
  url.scheme

func hostname*(url: URL): string {.inline, gcsafe.} =
  ## Get the hostname of a URL
  ##
  ## .. code-block:: Nim
  ##  import ferus_sanchar
  ##
  ##  let url = URL(
  ##    scheme: "https",
  ##    hostname: "google.com",
  ##    port: 443,
  ##    portRaw: "443",
  ##    path: "",
  ##    fragment: "",
  ##    query: ""
  ##  )
  ##
  ##  doAssert url.getHostname() == "google.com"
  url.hostname

func port*(url: URL): uint {.inline, gcsafe.} =
  ## Get the port of the URL which is an unsigned integer
  ##
  ## .. code-block:: Nim
  ##  import ferus_sanchar
  ##
  ##  let url = URL(
  ##    scheme: "https",
  ##    hostname: "google.com",
  ##    port: 443,
  ##    portRaw: "443",
  ##    path: "",
  ##    fragment: "",
  ##    query: ""
  ##  )
  ##
  ##  doAssert url.getPort() == 443
  url.port

func blob*(url: URL): Option[BlobURL] {.inline, gcsafe.} =
  ## Get the blob URL entry of the URL, granted that the URL has one
  ## .. code-block:: Nim
  ## import sanchar
  ## import std/options
  ## 
  ##  let url = URL(
  ##    scheme: "https",
  ##    hostname: "google.com",
  ##    port: 443,
  ##    portRaw: "443",
  ##    path: "",
  ##    fragment: "",
  ##    query: ""
  ##  )
  ##
  ##  doAssert url.blob() == none(BlobURL)

func path*(url: URL): string {.inline, gcsafe.} =
  ## Get the path of the URL, granted the URL has one
  ##
  ## .. code-block:: Nim
  ##  import ferus_sanchar
  ##
  ##  let url = URL(
  ##    scheme: "https",
  ##    hostname: "google.com",
  ##    port: 443,
  ##    portRaw: "443",
  ##    path: "",
  ##    fragment: "",
  ##    query: ""
  ##  )
  ##
  ##  doAssert url.getPath() == ""
  url.path

func fragment*(url: URL): string {.inline, gcsafe.} =
  ## Get the fragment of the URL, granted it exists
  ##
  ## .. code-block:: Nim
  ##  import ferus_sanchar
  ##
  ##  let url = URL(
  ##    scheme: "https",
  ##    hostname: "google.com",
  ##    port: 443,
  ##    portRaw: "443",
  ##    path: "",
  ##    fragment: "",
  ##    query: ""
  ##  )
  ##
  ##  doAssert url.getFragment() == ""
  url.fragment

func getTLD*(url: URL): string =
  ## Get the TLD domain for this URL. It does not need to be a real TLD (eg. test.blahblahblah).
  ##
  ## .. code-block:: Nim
  ##  import ferus_sanchar
  ##
  ##  let url = URL(
  ##    scheme: "https",
  ##    hostname: "google.com",
  ##    port: 443,
  ##    portRaw: "443",
  ##    path: "",
  ##    fragment: "",
  ##    query: ""
  ##  )
  ##
  ##  doAssert url.getTLD() == "com"
  var
    pos: int
    canInc = false
    tld: string

  while pos < url.hostname.len:
    canInc = url.hostname[pos] == '.'
    if canInc:
      break
    inc pos

  while pos < url.hostname.len:
    tld &= url.hostname[pos]
    inc pos

  tld

func query*(url: URL): string {.inline, gcsafe.} =
  ## Get the query segment of the URL, granted there was one.
  ##
  ## .. code-block:: Nim
  ##  import ferus_sanchar
  ##
  ##  let url = URL(
  ##    scheme: "https",
  ##    hostname: "google.com",
  ##    port: 443,
  ##    portRaw: "443",
  ##    path: "",
  ##    fragment: "",
  ##    query: ""
  ##  )
  ##
  ##  doAssert url.getQuery() == ""
  url.query

func newURL*(scheme, hostname, path, fragment: string, port: uint = 0): URL =
  ## Create a new URL object, takes in the scheme, hostname, path, fragment and port.
  ##
  ## .. code-block:: Nim
  ##  let url = newURL("https", "google.com", "", "", 443)
  var url = URL()

  url.scheme = scheme
  url.hostname = hostname
  url.path = path
  url.fragment = fragment

  if port == 0:
    if scheme in DEFAULT_PROTO_PORTS:
      url.port = DEFAULT_PROTO_PORTS[scheme]
    else:
      raise newException(
        URLException,
        "Port is 0 and \"" & scheme & "\" does not match any default protocol ports",
      )
  else:
    url.port = port

func encodeHostname(url: var URL) =
  var encodedComponents: seq[string]

  for component in url.hostname.split('.'):
    var encodedComponent =
      encode(component).strip(leading = false, trailing = true, chars = {'-'})

    if encodedComponent != component:
      encodedComponent = PUNYCODE_PREFIX & encodedComponent

    encodedComponents.add(encodedComponent)

  url.hostname = encodedComponents.join(".")

func urlError*(message: string) {.raises: [URLParseError].} =
  raise newException(URLParseError, message)

proc parse*(parser: var URLParser, src: string): URL =
  ## Parse a string into a URL, granted it is not malformed.
  ##
  ## .. code-block:: Nim
  ##  import ferus_sanchar
  ##
  ##  var urlParser = newURLParser()
  ##  let url = urlParser.parse("https://google.com")
  var
    pos: int
    curr: char
    url = URL()

  while pos < src.len:
    curr = src[pos]

    if parser.state == sInit:
      parser.state = parseScheme
      continue

    if parser.state == parseScheme:
      if curr != ':':
        url.scheme &= curr
      else:
        if url.scheme.len < 1:
          urlError("URL is missing scheme")

        parser.state = parseHostname
        pos += 3 # discard '//'
        if pos < src.len and src[pos - 1] == '/' and src[pos - 2] == '/':
          continue
        else:
          urlError("The scheme is supposed to be followed by two double slashes")
    elif parser.state == parseHostname:
      if url.scheme.len < 1:
        urlError("Failed to parse hostname as the scheme was not provided")

      if curr == '/':
        parser.state = parsePath
        pos += 1
        continue
      elif curr == '#':
        parser.state = parseFragment
        continue
      elif curr == ':':
        parser.state = parsePort
      elif curr == '?':
        parser.state = parseQuery
        continue
      else:
        url.hostname &= curr
    elif parser.state == parsePort:
      if url.scheme.len < 1:
        urlError("Failed to parse hostname as the scheme was not provided")

      template finalizePort =
        if url.portRaw.len > 0:
          url.port = try:
            parseUint(url.portRaw)
          except ValueError:
            urlError("URL port is invalid: " & url.portRaw)
            0'u
        elif url.scheme in DEFAULT_PROTO_PORTS:
          url.port = DEFAULT_PROTO_PORTS[url.scheme]

        if url.port > uint(uint16.high):
          urlError("URL port is out of range")

      if curr == '/':
        finalizePort
        parser.state = parsePath
        pos += 1
        continue
      elif curr == '#':
        finalizePort
        parser.state = parseFragment
        continue
      elif curr in {'0' .. '9'}:
        url.portRaw &= curr
      else:
        urlError("Invalid character found in port string: " & curr)
      
      if pos < src.len:
        finalizePort
    elif parser.state == parsePath:
      if url.scheme.len < 1:
        urlError("Failed to parse hostname as the scheme was not provided")

      if curr == '#':
        parser.state = parseFragment
        continue
      elif curr == '?':
        parser.state = parseQuery
        continue
      else:
        url.path &= curr
    elif parser.state == parseFragment:
      if url.scheme.len < 1:
        urlError("Failed to parse hostname as the scheme was not provided")

      if curr == '#':
        inc pos
        continue

      url.fragment &= curr
    elif parser.state == parseQuery:
      if url.scheme.len < 1:
        urlError("Failed to parse hostname as the scheme was not provided")

      if curr == '?':
        inc pos
        continue

      #[if curr.toLowerAscii() notin {'a'..'z'} and curr notin ['=', ' ']:
        raise newException(
            URLParseError, "Non-alphabetic character found in URL during query parsing!"
          )]#
      url.query &= curr

    inc pos

  parser.state = sInit

  url.encodeHostname()

  if not url.hostname.allCharsInSet(ALLOWED_HOSTNAME_CHARS):
    urlError("Invalid character found in hostname")

  url

func newURLParser*(): URLParser {.inline, noSideEffect.} =
  ## Create a new URL parser
  ## Initialize a new URLParser with the state set to sInit
  ##
  ## .. code-block:: Nim
  ##  var parser = newURLParser()
  URLParser(state: sInit)

proc parse*(src: string): URL {.inline.} =
  ## A shorthand function to create a URL parser, and parse a URL with it. 
  ## This is not recommended for high performance apps as a new URL parser is instantiated every time
  ## this function is called.
  var parser = newURLParser()
  parser.parse(src)

proc isValidUrl*(src: string): tuple[answer: bool, reason: string] {.inline.} =
  ## Check if a URL is valid/compliant. This is a simple try/catch clause to find any errors in a URL.
  ## .. code-block:: Nim
  ##  import sanchar
  ##
  ##  let validity = isValidUrl("http://verynicewebsite.com")
  ##
  ##  doAssert validity.answer == true
  var parser = newURLParser()
  try:
    discard parser.parse(src)
    return (answer: true, reason: "")
  except CatchableError as exc:
    return (answer: false, reason: exc.msg)
