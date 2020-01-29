use "ponytest"
use "collections"
use "fileext"
use "stringext"

primitive HelloWorldService is HttpService
	fun process(url:String box, params:Map[String,String] box, content:String box):(U32,String,String) =>
		(200, "text/plain", "Hello World")

actor Main
	new create(env: Env) =>
		try
			let server = HttpServer.listen("0.0.0.0", "8080")?
			server.registerService("/hello/world", HelloWorldService)
			server.registerService("*", HttpFileService("./public_html/"))
		end

 	fun @runtime_override_defaults(rto: RuntimeOptions) =>
		rto.ponyanalysis = false
		rto.ponynoscale = true
		rto.ponynoblock = true
		rto.ponynoyield = true
		rto.ponygcinitial = 0
		rto.ponygcfactor = 1.0

		/*
actor Main is TestList
	new create(env: Env) => PonyTest(env, this)
	new make() => None

	fun tag tests(test: PonyTest) =>
		test(_Test1)
	
 	fun @runtime_override_defaults(rto: RuntimeOptions) =>
		rto.ponyanalysis = false
		rto.ponynoscale = true
		rto.ponynoblock = true
		rto.ponynoyield = true
		rto.ponygcinitial = 0
		rto.ponygcfactor = 1.0

class iso _Test1 is UnitTest
	fun name(): String => "test 1 - in memory db"

	fun apply(h: TestHelper) =>
		try
			h.long_test(30_000_000_000)
			
			let server = HttpServer.listen("0.0.0.0", "8080")?
			server.registerService("/hello/world", HelloWorldService)
			server.registerService("*", SimpleFileService)
			
			
			h.complete(true)
		else
			h.complete(false)
		end

*/