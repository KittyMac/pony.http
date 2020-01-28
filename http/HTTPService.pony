use "collections"

trait HTTPService
	"""
	A service receives the parsed content of an HTTPServerConnection, processes it, and returns the
	payload to be returned to the client. HTTP services are inherently stateless, use HTTP[TBD]
	"""
	fun process(url:String box, params:Map[String,String] box, content:String box):(U32,String,String) =>
		(500, "text/plain", "Service Unavailable")
	
	fun httpStatusString(code:U32):String =>
		match code
		| 200 => "HTTP/1.1 200 OK"
		| 404 => "HTTP/1.1 404 Not Found"
		else "HTTP/1.1 500 Internal Server Error" end

primitive NullService is HTTPService
		