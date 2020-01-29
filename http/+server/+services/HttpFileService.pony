use "collections"
use "stringext"
use "fileext"

class HttpFileService is HttpService
	let webRoot:String
	let allowDotFiles:Bool

	new val default() =>
		webRoot = "./public_html/"
		allowDotFiles = false

	new val create(webRoot':String, allowDotFiles':Bool) =>
		webRoot = webRoot'
		allowDotFiles = allowDotFiles'
		

	fun process(url:String box, params:Map[String,String] box, content:String box):(U32,String,HttpContentResponse) =>
		try
			// 1. construct the path to the local file
			var fileURL = recover trn String(1024) end
			fileURL.append(webRoot)
			for c in url.values() do
				fileURL.push(c)
			end
			if StringExt.endswith(fileURL, "/") then
				fileURL.append("index.html")
			end
			
			// 2. Disallow going up directories (replace all .. with blanks)
			fileURL.replace("..", "", USize.max_value())
			
			// 3. Don't allow downloading of hidden files or directories?
			if (allowDotFiles == false) and fileURL.contains("/.") then
				return (404, "text/html; charset=UTF-8", "")
			end
			
			// 3. determine the content-type from the extension
			let extension = StringExt.pathExtension(fileURL)
			let contentType = httpContentTypeForExtension(extension)
			
			// 4. load file contents
			let fileURLVal:String val = consume fileURL
			let responseContent = FileExt.fileToArray(fileURLVal)?
						
			// 5. return results
			return (200, contentType, responseContent)
		else
			return (404, "text/html; charset=UTF-8", "")
		end