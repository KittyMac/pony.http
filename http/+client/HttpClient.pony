use "collections"
use "stringext"
use "net"

actor HttpClient
	"""
	Makes connection to server, handles sending and receiving HTTP 1.1 requests.
	"""
	
	var event:AsioEventID = AsioEvent.none()
	var socket:U32 = 0
	
	var pendingRequestWrites:Array[HttpRequest]
	var pendingRequestReads:Array[HttpRequest]
	
	new create() =>
		pendingRequestWrites = Array[HttpRequest](128)
		pendingRequestReads = Array[HttpRequest](128)
	
	new connect(host:String, port:String, from: String = "")? =>
		pendingRequestWrites = Array[HttpRequest](128)
		pendingRequestReads = Array[HttpRequest](128)
		
		@pony_os_connect_tcp4[U32](this, host.cstring(), port.cstring(), from.cstring(), AsioEvent.read_write_oneshot())
		
		if false then error end
	
	fun _is_sock_connected(fd: U32): Bool =>
		(let errno: U32, let value: U32) = OSSocket.get_so_error(fd)
		(errno == 0) and (value == 0)
	
	be _event_notify(event': AsioEventID, flags: U32, arg: U32) =>
	
		// if we receive an event and its writable, this is the clue we need that
		// the tcp connection has completed successfully
		if event isnt event' then
			if AsioEvent.writeable(flags) and (socket == 0) then
				event = event'
				socket = @pony_asio_event_fd(event)
				if _is_sock_connected(socket) then
					//@fprintf[I32](@pony_os_stdout[Pointer[U8]](), "socket connected on fd %d\n".cstring(), socket)
			        @pony_asio_event_set_writeable(event, false)
			        @pony_asio_event_resubscribe_write(event)
				else
					close()
				end
			end
		else
			if AsioEvent.writeable(flags) then
				try
					let request = pendingRequestWrites(0)?
					if request.write(event) then
						pendingRequestWrites.pop()?
						pendingRequestReads.push(request)
					end
				end
			end
			
			if AsioEvent.readable(flags) then
				try
					let request = pendingRequestReads(0)?
					if request.read(event) then
						pendingRequestWrites.pop()?
					end
				end
			end
			
		end
		
		
	be httpGet(notify:HttpRequestNotify, urlPath:String) =>
		let request = HttpRequest(notify, StringExt.format("GET %s HTTP/1.1\r\nUser-Agent: Pony/0.1\r\n\r\n", urlPath))
		pendingRequestWrites.push(request)
		
	fun ref close() =>
		if event != AsioEvent.none() then
	        @pony_asio_event_unsubscribe(event)
			event = AsioEvent.none()
	
			@pony_os_socket_close[None](socket)			
			socket = 0
		end
		