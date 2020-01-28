use "ponytest"
use "collections"
use "fileext"
use "stringext"

primitive SimpleFileService is HTTPService
	fun process(url:String box, params:Map[String,String] box, content:String box):(U32,String,String) =>
		try
			// 1. construct the path to the local file
			var fileURL:String val = "./public_html/" + url
			if StringExt.endswith(fileURL, "/") then
				fileURL = fileURL + "index.html"
			end
			
			// 2. determine the content-type from the extension
			let extension = StringExt.pathExtension(fileURL)
			let contentType = httpContentTypeForExtension(extension)
			
			// 3. load file contents
			let responseContent = recover val FileExt.fileToString(fileURL)? end
			
			// 4. return results
			return (200, contentType, responseContent)
		else
			return (404, "text/html; charset=UTF-8", "")
		end


primitive HelloWorldService is HTTPService
	fun process(url:String box, params:Map[String,String] box, content:String box):(U32,String,String) =>
		(200, "text/plain", "Hello World")

actor Main
	new create(env: Env) =>
		try
			let server = HttpServer.listen("0.0.0.0", "8080")?
			server.registerService("/hello/world", HelloWorldService)
			server.registerService("*", SimpleFileService)
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
		rto.ponyanalysis = true
		rto.ponynoscale = true
		rto.ponynoblock = true
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