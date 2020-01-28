use @strncmp[I32](s1:Pointer[U8] tag, s2:Pointer[U8] tag, size:USize)

actor HTTPServerConnection
	"""
	Handles a single HTTP server connection.  Read buffer has a single max size to it, if we read more than that we
	close the connection.
	"""
	let server:HTTPServer
	
	var event:AsioEventID = AsioEvent.none()
	var socket:U32 = 0
	
	let maxReadBufferSize:USize = 5 * 1024 * 1024
	var readBuffer:Array[U8]
	var scanOffset:USize = 0
	var scanContentLength:USize = 0
	
	var prevScanCharA:U8 = 0
	var prevScanCharB:U8 = 0
	var prevScanCharC:U8 = 0
	
	var httpCommand:U32 = HTTPCommand.none()
	var httpCommandUrl:String ref
	var httpContentLength:String ref
	var httpContentType:String ref
	var httpContent:String ref
	
	
	new create(server':HTTPServer) =>
		server = server'
		readBuffer = Array[U8](maxReadBufferSize)
		httpCommandUrl = String(1024)
		httpContentLength = String(1024)
		httpContentType = String(1024)
		httpContent = String(maxReadBufferSize)
	
	be process(socket':U32) =>
		socket = socket'
		
		@fprintf[I32](@pony_os_stdout[Pointer[U8]](), "connection open %d\n".cstring(), socket)
		
		scanOffset = 0
		scanContentLength = 0
		readBuffer.clear()
		
		httpCommand = HTTPCommand.none()
		httpCommandUrl.clear()
		httpContentLength.clear()
		httpContentType.clear()
		httpContent.clear()
		
		event = @pony_asio_event_create(this, socket, AsioEvent.read_write_oneshot(), 0, true)
	
	be _event_notify(event': AsioEventID, flags: U32, arg: U32) =>
		if event isnt event' then
			return
		end
				
		// perform our writes?
		if AsioEvent.writeable(flags) then
			None
		end
		
		// perform our reads?
		if AsioEvent.readable(flags) then
			read()
		end

		if AsioEvent.disposable(flags) then
			close()
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
	
	fun ref read() =>
		while true do
			try
				let len = @pony_os_recv[USize](event, readBuffer.cpointer(readBuffer.size()), maxReadBufferSize - readBuffer.size())?
				if len == 0 then
		            @pony_asio_event_set_readable[None](event, false)
		            @pony_asio_event_resubscribe_read(event)
					@ponyint_actor_yield[None](this)
					break
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
					//@fprintf[I32](@pony_os_stdout[Pointer[U8]](), "%c".cstring(), c)
					
					if 	(prevScanCharA == 'P') and (prevScanCharB == 'O') and (prevScanCharC == 'S') and (c == 'T') and matchScan("POST") then
						httpCommand = HTTPCommand.post()
						scanURL(scanOffset-3, httpCommandUrl)
					elseif (prevScanCharA == 'P') and (prevScanCharB == 'U') and (prevScanCharC == 'T') and (c == ' ') and matchScan("PUT ") then
						httpCommand = HTTPCommand.put()
						scanURL(scanOffset-3, httpCommandUrl)
					elseif (prevScanCharA == 'G') and (prevScanCharB == 'E') and (prevScanCharC == 'T') and (c == ' ') and matchScan("GET ") then
						httpCommand = HTTPCommand.get()
						scanURL(scanOffset-3, httpCommandUrl)
					elseif (prevScanCharA == 'L') and (prevScanCharB == 'E') and (prevScanCharC == 'T') and (c == 'E') and matchScan("DELETE") then
						httpCommand = HTTPCommand.delete()
						scanURL(scanOffset-5, httpCommandUrl)
					elseif (prevScanCharA == 'g') and (prevScanCharB == 't') and (prevScanCharC == 'h') and (c == ':') and matchScan("Content-Length:") then
						scanHeader(scanOffset-5, httpContentLength)
					elseif (prevScanCharA == 'y') and (prevScanCharB == 'p') and (prevScanCharC == 'e') and (c == ':') and matchScan("Content-Type:") then
						scanHeader(scanOffset-5, httpContentType)
					elseif (prevScanCharA == '\r') and (prevScanCharB == '\n') and (prevScanCharC == '\r') and (c == '\n') then
						try scanContentLength = httpContentLength.usize()? end
						if scanContentLength == 0 then
							break
						end
						continue
					end
					
					
					
					if scanContentLength == 0 then
						prevScanCharA = prevScanCharB
						prevScanCharB = prevScanCharC
						prevScanCharC = c
					
						scanOffset = scanOffset + 1
					else
						httpContent.push(c)
						scanContentLength = scanContentLength - 1
						if scanContentLength == 0 then
							// We are now completely done!
														
							@fprintf[I32](@pony_os_stdout[Pointer[U8]](), "httpCommand: %d\n".cstring(), httpCommand)
							@fprintf[I32](@pony_os_stdout[Pointer[U8]](), "httpCommandUrl: %s\n".cstring(), httpCommandUrl.cstring())
							@fprintf[I32](@pony_os_stdout[Pointer[U8]](), "httpContentLength: %s\n".cstring(), httpContentLength.cstring())
							@fprintf[I32](@pony_os_stdout[Pointer[U8]](), "httpContentType: %s\n".cstring(), httpContentType.cstring())
							@fprintf[I32](@pony_os_stdout[Pointer[U8]](), "httpContent: %s\n".cstring(), httpContent.cstring())
							
						end
					end
				end
				
			else
				close()
				break
			end
		end
		
	
	be close() =>
		
		@fprintf[I32](@pony_os_stdout[Pointer[U8]](), "connection closed %d\n".cstring(), socket)
		
		@pony_asio_event_destroy(event)
		@pony_os_socket_close[None](socket)
		
		event = AsioEvent.none()
		readBuffer.clear()
		socket = 0
		
		server.connectionFinished(this)
