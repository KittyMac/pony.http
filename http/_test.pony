use "ponytest"
use "collections"
use "fileext"
use "stringext"

primitive HelloWorldService is HttpService
	fun process(url:String box, params:Map[String,String] box, content:String box):(U32,String,HttpContentResponse) =>
		(200, "text/plain", "Hello World")

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






actor _Test1Actor
	let h: TestHelper
	new create(h': TestHelper)? =>
		h = h'
		
		let server = HttpServer.listen("0.0.0.0", "8080")?
		server.registerService("/hello/world", HelloWorldService)
		server.registerService("*", HttpFileService.default())
	
		let client = HttpClient.connect("127.0.0.1", "8080")?
		client.httpGet(this, "/index.html")
	
	be httpResponse(headers:Array[U8] val, content:Array[U8] val) =>
		try
			h.complete(FileExt.fileToString("./public_html/index.html")? == String.from_array(content))
		else
			h.complete(false)
		end

class iso _Test1 is UnitTest
	fun name(): String => "test 1 - request and compare index.html"

	fun apply(h: TestHelper) =>
		try
			h.long_test(30_000_000_000)
			_Test1Actor(h)?
		else
			h.complete(false)
		end
