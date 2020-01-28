all:
	stable env /Volumes/Development/Development/pony/ponyc/build/release/ponyc --sync-actor-constructors -o ./build/ ./http
	./build/http

debug:
	stable env /Volumes/Development/Development/pony/ponyc/build/debug/ponyc --sync-actor-constructors -d -o ./build/ ./http
	./build/http

bench-helloworld:
	wrk -t 4 -c 100 -d30s --timeout 2000 http://0.0.0.0:8080/hello/world

bench-html:
	wrk -t 4 -c 100 -d30s --timeout 2000 http://0.0.0.0:8080/index.html