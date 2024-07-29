import unittest
import sanchar/http

suite "basic https client":
  var client = httpClient()
  client.addHeader("User-Agent", "ferus_sanchar testing suite")
  test "https/get":
    let resp = client.get(
      parse("https://www.google.com")
    )

    check resp.code == 200
    check resp.content.len > 0
