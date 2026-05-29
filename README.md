**WARNING**: This package is deprecated. Do not use it!
- For the URL parser, you should use [nim-url](https://github.com/xTrayambak/url) instead, as it is more efficient on larger URLs and much more compatible.
- For the HTTP client, you should use `std/httpclient` or if you need a HTTP/2 client, use [hyperx](https://github.com/nitely/nim-hyperx).

# ferus-sanchar v2: a rewrite of the original ferus-sanchar library
This time around, the library has been mostly rewritten with a cleaner API in mind. \
It has no dependencies other than the Nim standard library, granted that `nph` is only used as a code formatter and `drchaos` is used to fuzz the URL parser.
