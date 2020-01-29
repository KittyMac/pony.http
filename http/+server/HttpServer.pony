use "collections"

use @pony_asio_event_create[AsioEventID](owner: AsioEventNotify, fd: U32, flags: U32, nsec: U64, noisy: Bool)
use @pony_asio_event_fd[U32](event: AsioEventID)
use @pony_asio_event_unsubscribe[None](event: AsioEventID)
use @pony_asio_event_resubscribe_read[None](event: AsioEventID)
use @pony_asio_event_resubscribe_write[None](event: AsioEventID)
use @pony_asio_event_destroy[None](event: AsioEventID)
use @pony_asio_event_get_disposable[Bool](event: AsioEventID)
use @pony_asio_event_set_writeable[None](event: AsioEventID, writeable: Bool)
use @pony_asio_event_set_readable[None](event: AsioEventID, readable: Bool)
use @ponyint_actor_num_messages[USize](anyActor:Any tag)

actor HttpServer
	"""
	Listens for initial connections, then passes the connection on to a pool of HttpServerConnections
	"""
	var event:AsioEventID = AsioEvent.none()
	var closed:Bool = true
	var socket: U32 = 0
	
	var connectionPool:Array[HttpServerConnection]
	var totalConnections:USize = 0
	
	var httpServices:Map[String box,HttpService val] val
	
	
	fun _tag():USize => 1
	fun _batch():USize => 5_000
	fun _priority():USize => -1
	
	new create() =>
		connectionPool = Array[HttpServerConnection]()
		httpServices = recover Map[String box,HttpService val]() end
	
	new listen(host:String, port:String)? =>
		connectionPool = Array[HttpServerConnection](2048)
		httpServices = recover Map[String box,HttpService val]() end
		
		event = @pony_os_listen_tcp4[AsioEventID](this, host.cstring(), port.cstring())
		socket = @pony_asio_event_fd(event)

		if socket < 0 then
			@pony_asio_event_unsubscribe(event)
			event = AsioEvent.none()
			error
		end
		
		closed = false
	
	fun ref close() =>
		if closed then
			return
		end

		closed = true

		if not event.is_null() then
			@pony_asio_event_unsubscribe(event)
			@pony_os_socket_close[None](socket)
			event = AsioEvent.none()
			socket = -1
		end
	
	be _event_notify(event': AsioEventID, flags: U32, arg: U32) =>
		//@fprintf[I32](@pony_os_stdout[Pointer[U8]](), "server event %d == %d\n".cstring(), event', event)
		if AsioEvent.disposable(flags) then
			@pony_asio_event_destroy(event')
			return
		end
		
		if event is event' then
			if AsioEvent.readable(flags) then
				
				// accept new connections and hand them to free (or new) connection processors
				while true do
					var connectionSocket = @pony_os_accept[U32](event)
					if connectionSocket == -1 then
						continue
					elseif connectionSocket == 0 then
						return
					end
			
					if connectionPool.is_empty() then
						HttpServerConnection(this).process(connectionSocket, httpServices)
					else
						try connectionPool.pop()?.process(connectionSocket, httpServices) end
					end
				end
				
			end
		end

		
	
	be registerService(url:String val, service:HttpService val) =>
		let httpServicesTrn:Map[String box,HttpService val] trn = recover Map[String box,HttpService val]() end
		
		// Copy over all of the existing services
		for (k, v) in httpServices.pairs() do
			httpServicesTrn(k) = v
		end
		httpServicesTrn(url) = service
		
		httpServices = consume httpServicesTrn		
		
		
	be connectionFinished(connection:HttpServerConnection) =>
		connectionPool.push(connection)
