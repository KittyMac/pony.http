all:
	corral exec -- ponyc --sync-actor-constructors -o ./build/ ./http
	./build/http

test:
	corral exec -- ponyc --sync-actor-constructors -V=0 -o ./build/ ./http
	./build/http

bench-helloworld:
	wrk -t 4 -c 100 -d30s --timeout 2000 http://0.0.0.0:8080/hello/world

bench-html:
	wrk -t 4 -c 100 -d30s --timeout 2000 http://0.0.0.0:8080/index.html


# wrk -t 4 -c 100 -d30s --timeout 2000 http://localhost:8080

corral-fetch:
	@corral clean -q
	@corral fetch -q

corral-local:
	-@rm corral.json
	-@rm lock.json
	@corral init -q
	@corral add /Volumes/Development/Development/pony/pony.fileExt -q
	@corral add /Volumes/Development/Development/pony/pony.flow -q
	@corral add /Volumes/Development/Development/pony/pony.stringExt -q
	@corral add /Volumes/Development/Development/pony/pony.ttimer -q
	@corral add /Volumes/Development/Development/pony/regex -q

corral-git:
	-@rm corral.json
	-@rm lock.json
	@corral init -q
	@corral add github.com/KittyMac/pony.fileExt.git -q
	@corral add github.com/KittyMac/pony.flow.git -q
	@corral add github.com/KittyMac/pony.stringExt.git -q
	@corral add github.com/KittyMac/pony.ttimer.git -q
	@corral add github.com/KittyMac/regex.git -q

ci: corral-git corral-fetch all
	
dev: corral-local corral-fetch all

