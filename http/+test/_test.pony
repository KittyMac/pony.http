use "ponytest"
use "collections"
use "fileext"
use "stringext"

primitive HelloWorldService is HttpService
	fun process(url:String val, content:Array[U8] val):(U32,String,HttpContentResponse) =>
		(200, "text/plain", "Hello World")

class TestJsonAPI is HttpService
	// look up and return people by matching first name or last name
	// TODO: add support for stateful services?  Or should all HttpService classes be immutable and
	// they should call to their own actor
	// TODO: What to do if the answer takes time to get (ie if we want to pull information from a
	// DB, then we need to call back to the HttpServerConnection and we cannot return immediately)
	let people:PersonResponse val
	
	new val create() =>
		people = try
				recover val PersonResponse.fromString(PersonDataJson())? end
			else
				recover val PersonResponse.empty() end
			end
		
		fun process(url:String val, content:Array[U8] val):(U32,String,HttpContentResponse) =>
		try
			let request = PersonRequest.fromString(String.from_array(content))?
			let response = recover val 
					let response' = PersonResponse.empty()
					for person in people.values() do
						if (person.firstName == request.firstName) or (person.lastName == request.lastName) then
							response'.push(person.clone()?)
						end
					end
					response'
				end
			return (200, "application/json", response.string())
		else
			(500, "text/html", "Service Unavailable")
		end





actor Main is TestList
	new create(env: Env) => PonyTest(env, this)
	new make() => None

	fun tag tests(test: PonyTest) =>
		
		try
			let server = HttpServer.listen("0.0.0.0", "8080")?
			server.registerService("/api/person", TestJsonAPI)
			server.registerService("/hello/world", HelloWorldService)
			server.registerService("*", HttpFileService.default())
		end
		
		test(_Test1)
		test(_Test2)
		test(_Test3)
		test(_Test4)
		test(_Test5)
	
 	fun @runtime_override_defaults(rto: RuntimeOptions) =>
		rto.ponyanalysis = false
		rto.ponynoscale = true
		rto.ponynoblock = true
		rto.ponynoyield = true
		rto.ponygcinitial = 0
		rto.ponygcfactor = 1.0


	
class iso _Test1 is UnitTest
	fun name(): String => "test 1 - request and compare index.html"

	fun apply(h: TestHelper) =>
		try
			h.long_test(30_000_000_000)
			
			let client = HttpClient.connect("127.0.0.1", "8080")?
			client.httpGet("/index.html", {(response:HttpResponseHeader val, content:Array[U8] val)(h) => 
				try
					if response.statusCode != 200 then
						error
					end
					h.complete(FileExt.fileToArray("./public_html/index.html")?.size() == content.size())
				else
					h.complete(false)
				end
			})
			
		else
			h.complete(false)
		end

class iso _Test2 is UnitTest
	fun name(): String => "test 2 - 404 error"

	fun apply(h: TestHelper) =>
		try
			h.long_test(30_000_000_000)
	
			let client = HttpClient.connect("127.0.0.1", "8080")?
			client.httpGet("/file_which_does_not_exist.html", {(response:HttpResponseHeader val, content:Array[U8] val)(h) => 
				h.complete((response.statusCode == 404) and (response.contentLength == 126))
			})
	
		else
			h.complete(false)
		end

class iso _Test3 is UnitTest
	fun name(): String => "test 3 - large file download"

	fun apply(h: TestHelper) =>
		try
			h.long_test(30_000_000_000)

			let client = HttpClient.connect("127.0.0.1", "8080")?
			client.httpGet("/big2.lz", {(response:HttpResponseHeader val, content:Array[U8] val)(h) => 
				try
					if response.statusCode != 200 then
						error
					end
					h.complete(FileExt.fileToArray("./public_html/big2.lz")?.size() == content.size())
				else
					h.complete(false)
				end
			})

		else
			h.complete(false)
		end

class iso _Test4 is UnitTest
	fun name(): String => "test 4 - json api request/response"

	fun apply(h: TestHelper) =>
		try
			h.long_test(30_000_000_000)

			let client = HttpClient.connect("127.0.0.1", "8080")?
			
			let request = PersonRequest.empty()
			request.firstName = "Jane"
			
			client.httpPost("/api/person", request.string(), {(response:HttpResponseHeader val, content:Array[U8] val)(h) => 
				try
					if response.statusCode != 200 then
						error
					end

					let persons = PersonResponse.fromString(String.from_array(content))?
					let person = persons(0)?
					h.complete( (person.firstName == "Jane") and (person.age == 27) and (persons.size() == 1) )
				else
					h.complete(false)
				end
			})

		else
			h.complete(false)
		end

class iso _Test5 is UnitTest
	fun name(): String => "test 5 - www.chimerasw.com"

	fun apply(h: TestHelper) =>
		try
			h.long_test(30_000_000_000)

			let client = HttpClient.connect("www.chimerasw.com", "80")?
			client.httpGet("/index.html", {(response:HttpResponseHeader val, content:Array[U8] val)(h) => 
				h.complete(response.statusCode == 200)
			})

		else
			h.complete(false)
		end