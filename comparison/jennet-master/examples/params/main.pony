use "http"
use "../../jennet"

actor Main
  new create(env: Env) =>
    let auth =
      try
        env.root as AmbientAuth
      else
        env.out.print("unable to use network.")
        return
      end

    let j =
      Jennet(auth, env.out, "8080")
        .> get("/hello/world", H)

    let j' = consume val j
    try j'.serve()? else j'.dispose() end

primitive H is Handler
  fun apply(c: Context, req: Payload val): Context iso^ =>
    let res = Payload.response()
    res.add_chunk("Hello World")
    c.respond(req, consume res)
    consume c
