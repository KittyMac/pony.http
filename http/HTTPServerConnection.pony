use "ponytest"

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
	
	var prevScanCharA:U8 = 0
	var prevScanCharB:U8 = 0
	var prevScanCharC:U8 = 0
	
	
	new create(server':HTTPServer) =>
		server = server'
		readBuffer = Array[U8](maxReadBufferSize)
	
	be process(socket':U32) =>
		socket = socket'
		
		@fprintf[I32](@pony_os_stdout[Pointer[U8]](), "connection open %d\n".cstring(), socket)
		
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
					@fprintf[I32](@pony_os_stdout[Pointer[U8]](), "%c".cstring(), c)
					
					if 	(prevScanCharA == 'P') and (prevScanCharB == 'O') and (prevScanCharC == 'S') and (c == 'T') then
						// POST line?
						None
					elseif (prevScanCharA == 'P') and (prevScanCharB == 'U') and (prevScanCharC == 'T') and (c == ' ') then
						// PUT line?
						None
					elseif (prevScanCharA == 'G') and (prevScanCharB == 'E') and (prevScanCharC == 'T') and (c == ' ') then
						// GET line?
						None
					elseif (prevScanCharA == 'L') and (prevScanCharB == 'E') and (prevScanCharC == 'T') and (c == 'E') then
						// DELETE line?
						None
					elseif (prevScanCharA == 'g') and (prevScanCharB == 't') and (prevScanCharC == 'h') and (c == ':') then
						// Content-Length?
						None
					elseif (prevScanCharA == '\r') and (prevScanCharB == '\n') and (prevScanCharC == '\r') and (c == '\n') then
						// we found the end!
						
						break
					end
					
					prevScanCharA = prevScanCharB
					prevScanCharB = prevScanCharC
					prevScanCharC = c
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
