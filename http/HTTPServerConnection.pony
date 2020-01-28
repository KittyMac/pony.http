use "collections"

use @strncmp[I32](s1:Pointer[U8] tag, s2:Pointer[U8] tag, size:USize)
use @pony_os_errno[I32]()

actor HttpServerConnection
	"""
	Handles a single HTTP server connection.  Read buffer has a single max size to it, if we read more than that we
	close the connection.
	"""
	let server:HttpServer
	
	var event:AsioEventID = AsioEvent.none()
	var socket:U32 = 0
	
	var serviceMap:Map[String box,HTTPService val] val
	
	let maxReadBufferSize:USize = 5 * 1024 * 1024
	var readBuffer:Array[U8]
	var scanOffset:USize = 0
	var scanContentLength:USize = 0
	
	var prevScanCharA:U8 = 0
	var prevScanCharB:U8 = 0
	
	var httpCommand:U32 = HTTPCommand.none()
	var httpCommandUrl:String ref
	var httpContentLength:String ref
	var httpContentType:String ref
	var httpContent:String ref
	
	let maxHttpResponse:USize = 5 * 1024 * 1024
	let httpResponse:String ref
	
	fun _tag():USize => 2
	fun _batch():USize => 5_000
	fun _priority():USize => 1
	
	new create(server':HttpServer) =>
		server = server'
		
		serviceMap = recover Map[String box,HTTPService val]() end
		readBuffer = Array[U8](maxReadBufferSize)
		
		httpCommandUrl = String(1024)
		httpContentLength = String(1024)
		httpContentType = String(1024)
		httpContent = String(maxReadBufferSize)
		httpResponse = String(maxHttpResponse)
		
	be process(socket':U32, serviceMap':Map[String box,HTTPService val] val) =>
		socket = socket'
		serviceMap = serviceMap'
		
		//@fprintf[I32](@pony_os_stdout[Pointer[U8]](), "connection open %d\n".cstring(), socket)
		
		scanOffset = 0
		scanContentLength = 0
		readBuffer.clear()
		
		httpCommand = HTTPCommand.none()
		httpCommandUrl.clear()
		httpContentLength.clear()
		httpContentType.clear()
		httpContent.clear()
		httpResponse.clear()
		
		event = @pony_asio_event_create(this, socket, AsioEvent.read_write_oneshot(), 0, true)
		@pony_asio_event_set_writeable(event, true)
	
	be _event_notify(event': AsioEventID, flags: U32, arg: U32) =>
		//@fprintf[I32](@pony_os_stdout[Pointer[U8]](), "connection event %d == %d (disposable: %d)\n".cstring(), event', event, AsioEvent.disposable(flags))
		if AsioEvent.disposable(flags) then
			@pony_asio_event_destroy(event')
			return
		end
	
		if event is event' then
			// perform our writes?
			if AsioEvent.writeable(flags) then
				None
			end
		
			if AsioEvent.readable(flags) then
				if read() then
				
					// We've completely read the request, process it against the matching service
					var service:HTTPService val = NullService
					try
						service = serviceMap(httpCommandUrl)?
					else
						try
							service = serviceMap("*")?
						end
					end
					
					let response = service.process(httpCommandUrl, Map[String,String](), httpContent)
					try
						httpResponse.clear()
						httpResponse.append(service.httpStatusString(response._1))
						httpResponse.push('\r')
						httpResponse.push('\n')
						httpResponse.append("Content-Type: ")
						httpResponse.append(response._2)
						httpResponse.push('\r')
						httpResponse.push('\n')
						httpResponse.append("Content-Length: ")
						httpResponse.append(response._3.size().string())
						httpResponse.push('\r')
						httpResponse.push('\n')
						httpResponse.push('\r')
						httpResponse.push('\n')
						httpResponse.append(response._3)
						@pony_os_send[USize](event, httpResponse.cpointer(), httpResponse.size())?
					end
					
					resetWriteForNextResponse()
				end
				
				// If we get here and we're still active, we need to reschedule ourselves for more data
				if event != AsioEvent.none() then
					@pony_asio_event_set_readable[None](event, false)
					@pony_asio_event_resubscribe_read(event)
					@ponyint_actor_yield[None](this)
				end
			end
		end
	
	fun ref matchScan(string:String):Bool =>
		(@strncmp(readBuffer.cpointer((scanOffset-string.size())+1), string.cstring(), string.size()) == 0)
	
	fun ref scanURL(offset:USize, string:String ref) =>
		var spaceCount:USize = 0
		string.clear()
		for c in readBuffer.valuesAfter(offset) do
			if (c == ' ') or (c == '\n') or (c == '\r') then
				spaceCount = spaceCount + 1
				if spaceCount == 2 then
					return
				end
				continue
			end
			if (spaceCount == 1) then
				string.push(c)
			end
		end

	fun ref scanHeader(offset:USize, string:String ref) =>
		var separatorCount:USize = 0
		string.clear()
		for c in readBuffer.valuesAfter(offset) do
			if (separatorCount == 0) then
				if c == ':' then
					separatorCount = 1
				end
				continue
			end
			if (separatorCount == 1) then
				if (c == '\n') or (c == '\r') then
					return
				end
			end
			if (c != ' ') and (separatorCount == 1) then
				string.push(c)
			end
		end
	
	
	fun ref resetWriteForNextResponse() =>
		httpCommand = HTTPCommand.none()
		httpCommandUrl.clear()
		httpContentLength.clear()
		httpContentType.clear()
		httpContent.clear()
	
	fun ref resetReadForNextRequest() =>
		scanOffset = 0
		scanContentLength = 0
		readBuffer.clear()
	
	fun ref read():Bool =>
		try
			while true do
			
				let len = @pony_os_recv[USize](event, readBuffer.cpointer(readBuffer.size()), maxReadBufferSize - readBuffer.size())?
				if len == 0 then
					return false
				end
				readBuffer.undefined(readBuffer.size() + len)
				
				// Process the HTTP header as it arrives.  We're looking for several key this:
				// POST/PUT/GET/DELETE requests and the URL associated with them
				// Content-Length field, so we know how many bytes to read after then end of the header
				// 2x CRLF to signify the end of the HTTP header
				//
				// Example:
				//   POST /test.html HTTP/1.1
				//   Host: 127.0.0.1:8080
				//   User-Agent: curl/7.54.0
				//   Accept: */*
				//   Content-Type: application/json
				//   Content-Length: 26
				//   
				//   {"id":9,"name":"baeldung"}
				for c in readBuffer.valuesAfter(scanOffset) do					
					if 	(prevScanCharA == 'O') and (prevScanCharB == 'S') and (c == 'T') and matchScan("POST") then
						httpCommand = HTTPCommand.post()
						scanURL(scanOffset-3, httpCommandUrl)
					elseif (prevScanCharA == 'U') and (prevScanCharB == 'T') and (c == ' ') and matchScan("PUT ") then
						httpCommand = HTTPCommand.put()
						scanURL(scanOffset-3, httpCommandUrl)
					elseif (prevScanCharA == 'E') and (prevScanCharB == 'T') and (c == ' ') and matchScan("GET ") then
						httpCommand = HTTPCommand.get()
						scanURL(scanOffset-3, httpCommandUrl)
					elseif (prevScanCharA == 'E') and (prevScanCharB == 'T') and (c == 'E') and matchScan("DELETE") then
						httpCommand = HTTPCommand.delete()
						scanURL(scanOffset-5, httpCommandUrl)
					elseif (prevScanCharA == 't') and (prevScanCharB == 'h') and (c == ':') and matchScan("Content-Length:") then
						scanHeader(scanOffset-5, httpContentLength)
					elseif (prevScanCharA == 'p') and (prevScanCharB == 'e') and (c == ':') and matchScan("Content-Type:") then
						scanHeader(scanOffset-5, httpContentType)
					elseif (prevScanCharA == '\n') and (prevScanCharB == '\r') and (c == '\n') then
						try scanContentLength = httpContentLength.usize()? end
						if scanContentLength == 0 then
							resetReadForNextRequest()
							return true
						end
						continue
					end
					
					if scanContentLength == 0 then
						prevScanCharA = prevScanCharB
						prevScanCharB = c
					
						scanOffset = scanOffset + 1
					else
						httpContent.push(c)
						scanContentLength = scanContentLength - 1
						if scanContentLength == 0 then
							resetReadForNextRequest()
							return true
						end
					end
				end
			end
		else
			close()
		end
		
		false
		
	
	fun ref close() =>
		
		if event != AsioEvent.none() then
	        @pony_asio_event_unsubscribe(event)
			event = AsioEvent.none()
		
			@pony_os_socket_close[None](socket)			
			socket = 0
		
			server.connectionFinished(this)
		end
