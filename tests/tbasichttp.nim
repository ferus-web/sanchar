import unittest
import sanchar/http

suite "basic http client":
  var client = httpClient()
  client.addHeader("User-Agent", "ferus_sanchar testing suite")
  test "http/get":
    let resp = client.get(
      parse("http://motherfuckingwebsite.com")
    )

    check resp.code == 200
    check resp.content.len > 0
