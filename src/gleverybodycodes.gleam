import envoy
import gleam/bool
import gleam/dynamic/decode
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/io
import gleam/json
import gleam/option.{type Option, None}
import gleam/result
import gleam/string
import simplifile

fn get_home() -> Result(String, Nil) {
  case envoy.get("HOME") {
    Ok(home) -> Ok(home)
    Error(Nil) -> envoy.get("USERPROFILE")
  }
}

fn expand_home(path: String) -> Result(String, Nil) {
  use <- bool.guard(!string.contains(path, "~"), Ok(path))
  use home <- result.try(get_home())
  path |> string.replace("~", home) |> Ok()
}

// EC_CONFIG_DIR, EC_DATA_DIR, EC_TOKEN
fn get_token() -> Result(String, simplifile.FileError) {
  use _ <- result.try_recover(envoy.get("EC_TOKEN"))

  use path <- result.try(
    envoy.get("EC_CONFIG_DIR")
    |> result.unwrap("~/.config/ecd/token")
    |> expand_home()
    |> result.replace_error(simplifile.Unknown("Unable to expand ~")),
  )

  simplifile.read(path) |> result.map(string.trim_end)
}

type User {
  User(
    level: Int,
    seed: Int,
    penalty_until: Int,
    ai: Bool,
    streamer: Bool,
    server_time: Int,
    id: Option(Int),
    code: Option(String),
    name: Option(String),
    country: Option(String),
    url: Option(String),
    // badges: Option(Dict(String, String)), // Don't know what type badges is
  )
}

fn user_from_json(json_string: String) -> Result(User, json.DecodeError) {
  let user_decoder = {
    use level <- decode.field("level", decode.int)
    use seed <- decode.field("seed", decode.int)
    use penalty_until <- decode.field("penaltyUntil", decode.int)
    use ai <- decode.field("ai", decode.bool)
    use streamer <- decode.field("streamer", decode.bool)
    use server_time <- decode.field("serverTime", decode.int)
    use id <- decode.optional_field("id", None, decode.optional(decode.int))
    use code <- decode.optional_field(
      "code",
      None,
      decode.optional(decode.string),
    )
    use name <- decode.optional_field(
      "name",
      None,
      decode.optional(decode.string),
    )
    use country <- decode.optional_field(
      "country",
      None,
      decode.optional(decode.string),
    )
    use url <- decode.optional_field(
      "url",
      None,
      decode.optional(decode.string),
    )
    // Don't know what type badges is
    // use badges <- decode.optional_field(
    //   "badges",
    //   None,
    //   decode.optional(decode.dict),
    // )
    decode.success(User(
      level:,
      seed:,
      penalty_until:,
      ai:,
      streamer:,
      server_time:,
      id:,
      code:,
      name:,
      country:,
      url:,
    ))
  }
  json.parse(from: json_string, using: user_decoder)
}

fn get_me(token: String) {
  let assert Ok(base_req) = request.to("https://everybody.codes/api/user/me")

  let req =
    base_req
    |> request.prepend_header("accept", "application/json")
    |> request.prepend_header("User-Agent", "github.com/pf981/gleverybodycodes")
    |> request.prepend_header("Cookie", "everybody-codes=" <> token)

  // Send the HTTP request to the server
  use resp <- result.try(httpc.send(req))

  echo resp

  // We get a response record back
  assert resp.status == 200

  let content_type = echo response.get_header(resp, "content-type")
  assert content_type == Ok("application/json")

  // assert resp.body == "{\"message\":\"Hello World\"}"
  echo resp

  Ok(resp)
}

pub fn main() -> Nil {
  case get_token() {
    Ok(token) -> io.println(token)
    Error(_) -> io.println("Missing token")
  }
  let assert Ok(token) = get_token()

  let assert Ok(resp) = get_me(token)
  // let assert Ok(resp) = get_me("")

  echo resp.body

  let user = echo user_from_json(resp.body)

  Nil
}
