import unittest
import sanchar/parse/url

suite "url parsing suite":
  test "basic url": # if this fails, we're majestically screwed.
    let url = parse("https://example.com")

    check url.scheme == "https"
    check url.hostname == "example.com"

  test "url paths":
    let url = parse("https://example.com/this/is/a/very/real/path")

    check url.path == "this/is/a/very/real/path"

  test "url queries":
    let url = parse("https://example.com?this_is_a=very_real_query")

    check url.query == "this_is_a=very_real_query"

  test "default protocol ports":
    let
      http = parse("http://example.com")
      ftp = parse("ftp://example.com")
      gemini = parse("gemini://example.com")
      https = parse("https://example.com")
    
    check http.port == 80'u
    check https.port == 443'u
    check ftp.port == 20'u
    check gemini.port == 1965'u

  test "TLDs":
    let
      dotIn = parse("https://up.gov.in")
      dotRu = parse("https://genproc.gov.ru")
      dotUa = parse("https://bank.gov.ua")
      dotUs = parse("https://health.gov.us")

      dotCom = parse("https://google.com")
      dotIo = parse("https://icouldntthinkofacleverandfunnydomainthatendswith.io")
    
    check dotIn.getTld == ".gov.in"
    check dotRu.getTld == ".gov.ru"
    check dotUa.getTld == ".gov.ua"
    check dotUs.getTld == ".gov.us"
    check dotCom.getTld == ".com"
    check dotIo.getTld == ".io"

  test "url fragments":
    let url = parse("https://ferus.org#why-ferus-sucks")
    check url.fragment == "why-ferus-sucks"

  test "invalid hostname":
    expect URLParseError:
      let url = parse("https://inval!d.com")

  test "punycode hostname":
    let url = parse("https://xn--80aswg.xn--p1ai/")

    check url.scheme == "https"
    check url.hostname == "xn--80aswg.xn--p1ai"

  test "non-ASCII hostname":
    let 
      url = parse("https://сайт.рф")
      url2 = parse("https://xn--80aswg.xn--p1ai/")

    check url.scheme == "https"
    check url.hostname == "xn--80aswg.xn--p1ai"
    check url.hostname == url2.hostname
