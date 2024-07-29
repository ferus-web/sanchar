import unittest
import sanchar/parse/url

suite "url parsing suite":
  test "basic url": # if this fails, we're majestically screwed.
    let url = parse("https://example.com")

    doAssert url.scheme == "https"
    doAssert url.hostname == "example.com"

  test "url paths":
    let url = parse("https://example.com/this/is/a/very/real/path")

    doAssert url.path == "this/is/a/very/real/path", url.path

  test "url queries":
    let url = parse("https://example.com?this_is_a=very_real_query")

    doAssert url.query == "this_is_a=very_real_query", url.query

  test "default protocol ports":
    let
      http = parse("http://example.com")
      ftp = parse("ftp://example.com")
      gemini = parse("gemini://example.com")
      https = parse("https://example.com")
    
    doAssert http.port == 80'u, $http.port
    doAssert https.port == 443'u, $https.port
    doAssert ftp.port == 20'u, $ftp.port
    doAssert gemini.port == 1965'u, $gemini.port

  test "TLDs":
    let
      dotIn = parse("https://hell.gov.in")
      dotRu = parse("https://cykablyad.gov.ru")
      dotUa = parse("https://weneedfivebillionrockets.gov.ua")
      dotUs = parse("https://killingiraqichildrentutorial.gov.us")

      dotCom = parse("https://google.com")
      dotIo = parse("https://icouldntthinkofacleverandfunnydomainthatendswith.io")
    
    doAssert dotIn.getTld == ".gov.in", dotIn.getTld
    doAssert dotRu.getTld == ".gov.ru", dotRu.getTld
    doAssert dotUa.getTld == ".gov.ua", dotUa.getTld
    doAssert dotUs.getTld == ".gov.us", dotUs.getTld
    doAssert dotCom.getTld == ".com", dotCom.getTld
    doAssert dotIo.getTld == ".io", dotIo.getTld

  test "url fragments":
    let url = parse("https://ferus.org#why-ferus-sucks")

    doAssert url.fragment == "why-ferus-sucks", url.fragment

  test "invalid hostname":
    expect URLParseError:
      let url = parse("https://inval!d.com")

  test "punycode hostname":
    let url = parse("https://xn--80aswg.xn--p1ai/")

    doAssert url.scheme == "https"
    doAssert url.hostname == "xn--80aswg.xn--p1ai"

  test "non-ASCII hostname":
    let url = parse("https://сайт.рф")

    doAssert url.scheme == "https"
    doAssert url.hostname == "xn--80aswg.xn--p1ai"
