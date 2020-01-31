# pony.http

**WARNING** This code only compiles with [my fork of Pony](https://github.com/KittyMac/ponyc/tree/roc_master).

### Purpose

To provide a barebones http-like server for Pony, while also being a learning vehicle for me. 

Note: This is a very early and generally specialized implementation.  You should avoid using the code in this repository if you are looking for a full-featured http server.



### TODOs

- Http client connect to server code (in progress)

- Fail on http requests which exceed a maximum size
- Support more of things in HTTP 1.1 (specifically compression and ssl)

## License

pony.http is free software distributed under the terms of the MIT license, reproduced below. pony.http may be used for any purpose, including commercial purposes, at absolutely no cost. No paperwork, no royalties, no GNU-like "copyleft" restrictions. Just download and enjoy.

Copyright (c) 2019 Rocco Bowling

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.