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

actor HTTPServer
	"""
	Listens for initial connections, then passes the connection on to a pool of HTTPServerConnections
	"""
	var event:AsioEventID = AsioEvent.none()
	var closed:Bool = true
	var socket: U32 = 0
	
	var connectionPool:Array[HTTPServerConnection]
	
	new create() =>
		connectionPool = Array[HTTPServerConnection]()
	
	new listen(host:String, port:String)? =>
		connectionPool = Array[HTTPServerConnection](2048)
		
		event = @pony_os_listen_tcp4[AsioEventID](this, host.cstring(), port.cstring())
		socket = @pony_asio_event_fd(event)

		if socket < 0 then
			@pony_asio_event_destroy(event)
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
			socket = -1
		end
	
	be _event_notify(event': AsioEventID, flags: U32, arg: U32) =>
		if event isnt event' then
			return
		end

		if AsioEvent.readable(flags) then
			accept()
		end

		if AsioEvent.disposable(flags) then
			@pony_asio_event_destroy(event)
			event = AsioEvent.none()
		end
	
	fun ref accept() =>
		if closed then
			return
		end

		var connectionSocket = @pony_os_accept[U32](event)
		if connectionSocket > 0 then
			spawn(connectionSocket)
		end
	
	fun ref spawn(connectionSocket: U32) =>
		if connectionPool.is_empty() then
			connectionPool.push(HTTPServerConnection(this))
		end
		
		try
			let connection = connectionPool.pop()?
			connection.process(connectionSocket)
		else
			@pony_os_socket_close[None](connectionSocket)
		end
	
	be connectionFinished(connection:HTTPServerConnection) =>
		connectionPool.push(connection)
