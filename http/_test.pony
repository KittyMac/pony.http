use "ponytest"
use "collections"
use "fileext"
use "stringext"

primitive FileService is HTTPService
	fun process(url:String box, params:Map[String,String] box, content:String box):(U32,String,String) =>
		try
			// 1. construct the path to the local file
			var fileURL:String val = "./public_html/" + url
			if StringExt.endswith(fileURL, "/") then
				fileURL = fileURL + "index.html"
			end
			
			// 2. determine the content-type from the extension
			let extension = StringExt.pathExtension(fileURL)
			let contentType = match extension
			| ".arc" => "application/x-freearc"
			| ".avi" => "video/x-msvideo"
			| ".azw" => "application/vnd.amazon.ebook"
			| ".bin" => "application/octet-stream"
			| ".bmp" => "image/bmp"
			| ".bz" => 	"application/x-bzip"
			| ".bz2" => "application/x-bzip2"
			| ".csh" => "application/x-csh"
			| ".css" => "text/css"
			| ".csv" => "text/csv"
			| ".doc" => "application/msword"
			| ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
			| ".eot" => "application/vnd.ms-fontobject"
			| ".epub" => "application/epub+zip"
			| ".gz" => 	"application/gzip"
			| ".gif" => "image/gif"
			| ".htm" => "text/html"
			| ".html" => "text/html"
			| ".ico" => "image/vnd.microsoft.icon"
			| ".ics" => "text/calendar"
			| ".jar" => "application/java-archive"
			| ".jpeg" => "image/jpeg"
			| ".jpg" => "image/jpeg"
			| ".js" => "text/javascript"
			| ".json" => "application/json"
			| ".jsonld" => "application/ld+json"
			| ".mid" => "audio/midi"
			| ".midi" => "audio/midi"
			| ".mjs" => "text/javascript"
			| ".mp3" => "audio/mpeg"
			| ".mpeg" => "video/mpeg"
			| ".mpkg" => "application/vnd.apple.installer+xml"
			| ".odp" => "application/vnd.oasis.opendocument.presentation"
			| ".ods" => "application/vnd.oasis.opendocument.spreadsheet"
			| ".odt" => "application/vnd.oasis.opendocument.text"
			| ".oga" => "audio/ogg"
			| ".ogv" => "video/ogg"
			| ".ogx" => "application/ogg"
			| ".opus" => "audio/opus"
			| ".otf" => "font/otf"
			| ".png" => "image/png"
			| ".pdf" => "application/pdf"
			| ".php" => "application/php"
			| ".ppt" => "application/vnd.ms-powerpoint"
			| ".pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation"
			| ".rar" => "application/x-rar-compressed"
			| ".rtf" => "application/rtf"
			| ".sh" => "application/x-sh"
			| ".svg" => "image/svg+xml"
			| ".swf" => "application/x-shockwave-flash"
			| ".tar" => "application/x-tar"
			| ".tif" => "image/tiff"
			| ".tiff" => "image/tiff"
			| ".ts" => "video/mp2t"
			| ".ttf" => "font/ttf"
			| ".txt" => "text/plain"
			| ".vsd" => "application/vnd.visio"
			| ".wav" => "audio/wav"
			| ".weba" => "audio/webm"
			| ".webm" => "video/webm"
			| ".webp" => "image/webp"
			| ".woff" => "font/woff"
			| ".woff2" => "font/woff2"
			| ".xhtml" => "application/xhtml+xml"
			| ".xls" => "application/vnd.ms-excel"
			| ".xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
			| ".xml" => "application/xml"
			| ".xul" => "application/vnd.mozilla.xul+xml"
			| ".zip" => "application/zip"
			| ".3gp" => "video/3gpp"
			| ".3g2" => "video/3gpp2"
			| ".7z" => "application/x-7z-compressed"
			else "text/html" end
			
			// 3. load file contents
			let responseContent = recover val FileExt.fileToString(fileURL)? end
			
			// 4. return results
			return (200, contentType, responseContent)
		else
			return (404, "text/html; charset=UTF-8", "")
		end


actor Main is TestList
	new create(env: Env) => PonyTest(env, this)
	new make() => None

	fun tag tests(test: PonyTest) =>
		test(_Test1)

class iso _Test1 is UnitTest
	fun name(): String => "test 1 - in memory db"

	fun apply(h: TestHelper) =>
		try
			h.long_test(30_000_000_000)
			
			let server = HTTPServer.listen("0.0.0.0", "8080")?
			server.registerService("*", FileService)
			
			
			h.complete(true)
		else
			h.complete(false)
		end

