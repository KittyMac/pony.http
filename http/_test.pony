use "ponytest"

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
			
			HTTPServer.listen("0.0.0.0", "8080")?
			
			h.complete(true)
		else
			h.complete(false)
		end

