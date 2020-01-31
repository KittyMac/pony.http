use "collections"
use "stringext"
use "net"


primitive HttpRequestState
	fun header():U32 => 0
	fun content():U32 => 1
	fun finished():U32 => 2

interface tag HttpRequestNotify
	be httpResponse(headers:Array[U8] val, content:Array[U8] val)
		

class HttpRequest
	let httpRequestString:String val
	
	var httpResponseHeaderBuffer:Array[U8] trn
	var httpResponseContentBuffer:Array[U8] trn
	
	let maxHttpResponseHeaderSize:USize = 2048
	
	var writeOffset:USize = 0
	
	var readOffset:USize = 0
	var readContentLength:USize = 0
	
	var prevScanCharA:U8 = 0
	var prevScanCharB:U8 = 0
	
	var httpContentLength:String ref
	var httpContentType:String ref
	var httpStatus:String ref
	var httpStatusCode:U32 = 0
	
	var notify:HttpRequestNotify
	
	var requestState:U32 = HttpRequestState.header()
	

	new create(notify':HttpRequestNotify, httpRequestString':String) =>
		notify = notify'
		
		httpRequestString = httpRequestString'
		httpResponseHeaderBuffer = recover Array[U8](maxHttpResponseHeaderSize) end
		httpResponseContentBuffer = recover Array[U8](maxHttpResponseHeaderSize) end
		
		httpContentLength = String(128)
		httpContentType = String(128)
		httpStatus = String(10)
	
	fun ref matchScan(string:String):Bool =>
		(@strncmp(httpResponseHeaderBuffer.cpointer((readOffset-string.size())+1), string.cstring(), string.size()) == 0)
	
	fun ref scanHttpStatus(offset:USize, string:String ref) =>
		// HTTP/1.1 200 OK
		var separatorCount:USize = 0
		string.clear()
		for c in httpResponseHeaderBuffer.valuesAfter(offset) do
			if c == ' ' then
				separatorCount = separatorCount + 1
			elseif (c == '\n') or (c == '\r') then
				return
			elseif (separatorCount == 1) then
				string.push(c)
			end
		end
	
	fun ref scanHeader(offset:USize, string:String ref) =>
		// Content-Type: text/html
		var separatorCount:USize = 0
		string.clear()
		for c in httpResponseHeaderBuffer.valuesAfter(offset) do
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
	
	fun ref consumeField(fieldVal:Array[U8] val):(Array[U8] trn^, Array[U8] val) =>
		(recover trn Array[U8] end, fieldVal)
	
	fun ref finished() =>
		requestState = HttpRequestState.finished()
		
		(httpResponseHeaderBuffer, let header) = consumeField(consume httpResponseHeaderBuffer)
		(httpResponseContentBuffer, let content) = consumeField(consume httpResponseContentBuffer)
		notify.httpResponse(header, content)
	
	fun ref write(event:AsioEventID):Bool =>
		try
			while writeOffset < httpRequestString.size() do
				let n = @pony_os_send[USize](event, httpRequestString.cpointer(writeOffset), httpRequestString.size() - writeOffset)?
				if n == 0 then
			        @pony_asio_event_set_writeable(event, false)
			        @pony_asio_event_resubscribe_write(event)
					@ponyint_actor_yield[None](this)
					return false
				end
				writeOffset = writeOffset + n
			end
		else
			writeOffset = 0
		end
		true
	
	fun ref rescheduleForMoreReads(event:AsioEventID) =>
		@pony_asio_event_set_readable[None](event, false)
		@pony_asio_event_resubscribe_read(event)
		
	fun ref read(event:AsioEventID):Bool =>
		
		try
			while true do
				
				match requestState
				| HttpRequestState.header() =>
				
					let len = @pony_os_recv[USize](event, httpResponseHeaderBuffer.cpointer(httpResponseHeaderBuffer.size()), maxHttpResponseHeaderSize - httpResponseHeaderBuffer.size())?
					if len == 0 then
						return false
					end
					httpResponseHeaderBuffer.undefined(httpResponseHeaderBuffer.size() + len)
					
					// For the response we're looking at something like the following
					// 
					// HTTP/1.1 200 OK
					// Content-Type: text/html
					// Content-Length: 512
					// 
					// Right now we only care about the status code, the content-type and the content-length at the moment.
					for c in httpResponseHeaderBuffer.valuesAfter(readOffset) do						
						if requestState == HttpRequestState.content() then
							httpResponseContentBuffer.push(c)
							continue
						end
						
						if 	(prevScanCharA == 'T') and (prevScanCharB == 'T') and (c == 'P') and matchScan("HTTP") then
							scanHttpStatus(readOffset-3, httpStatus)
							try httpStatusCode = httpStatus.u32()? end
						elseif (prevScanCharA == 'p') and (prevScanCharB == 'e') and (c == ':') and matchScan("Content-Type:") then
							scanHeader(readOffset-5, httpContentType)
							elseif (prevScanCharA == 't') and (prevScanCharB == 'h') and (c == ':') and matchScan("Content-Length:") then
							scanHeader(readOffset-5, httpContentLength)
							try readContentLength = httpContentLength.usize()? end
							httpResponseContentBuffer.reserve(readContentLength)
						elseif (prevScanCharA == '\n') and (prevScanCharB == '\r') and (c == '\n') then
							if readContentLength == 0 then
								@fprintf[I32](@pony_os_stdout[Pointer[U8]](), "finished 1!\n".cstring())
								finished()
								return true
							end
							requestState = HttpRequestState.content()
							continue
						end
				
						prevScanCharA = prevScanCharB
						prevScanCharB = c
					
						readOffset = readOffset + 1
					end
					
					
				| HttpRequestState.content() =>
				let len = @pony_os_recv[USize](event, httpResponseContentBuffer.cpointer(httpResponseContentBuffer.size()), readContentLength - httpResponseContentBuffer.size())?
					if len == 0 then
						return false
					end
					httpResponseContentBuffer.undefined(httpResponseContentBuffer.size() + len)
					
					if httpResponseContentBuffer.size() >= readContentLength then
						finished()
						return true
					end
									
				end
								
			end
		end
		
		false
		
		
