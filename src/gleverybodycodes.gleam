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

fn get_home() -> Result(String, String) {
  case envoy.get("HOME") {
    Ok(home) -> Ok(home)
    Error(Nil) ->
      envoy.get("USERPROFILE")
      |> result.replace_error(
        "Unable to expand ~. $HOME and $USERPROFILE not set.",
      )
  }
}

fn expand_home(path: String) -> Result(String, String) {
  use <- bool.guard(!string.contains(path, "~"), Ok(path))
  use home <- result.try(get_home())
  path |> string.replace("~", home) |> Ok()
}

// EC_CONFIG_DIR, EC_DATA_DIR, EC_TOKEN
fn get_token() -> Result(String, String) {
  use _ <- result.try_recover(envoy.get("EC_TOKEN"))

  use path <- result.try(
    envoy.get("EC_CONFIG_DIR")
    |> result.unwrap("~/.config/ecd/token")
    |> expand_home(),
  )

  simplifile.read(path)
  |> result.map(string.trim_end)
  |> result.map_error(fn(e) {
    "Unable to read config file: "
    <> path
    <> "\n"
    <> simplifile.describe_error(e)
  })
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

fn json_error_to_string(error: json.DecodeError) -> String {
  echo error
  // TODO: Properly display decode errors
  "Unable to parse JSON"
}

fn http_error_to_string(error: httpc.HttpError) -> String {
  echo error
  "HTTP error: "
  <> case error {
    httpc.InvalidUtf8Response -> "Invalid UTF-8 response"
    httpc.FailedToConnect(ip4:, ip6:) -> {
      let ip4_string = case ip4 {
        httpc.Posix(code:) -> "Posix: " <> code
        httpc.TlsAlert(code:, detail:) -> "TLS: " <> code <> " - " <> detail
      }
      let ip6_string = case ip6 {
        httpc.Posix(code:) -> "Posix: " <> code
        httpc.TlsAlert(code:, detail:) -> "TLS: " <> code <> " - " <> detail
      }
      "Failed to connect\n" <> ip4_string <> "\n" <> ip6_string
    }
  }
}

fn get_me(token: String) -> Result(User, String) {
  let assert Ok(base_req) = request.to("https://everybody.codes/api/user/me")

  let req =
    base_req
    |> request.prepend_header("accept", "application/json")
    |> request.prepend_header("User-Agent", "github.com/pf981/gleverybodycodes")
    |> request.prepend_header("Cookie", "everybody-codes=" <> token)

  // Send the HTTP request to the server
  use resp <- result.try(
    httpc.send(req) |> result.map_error(http_error_to_string),
  )

  echo resp

  // We get a response record back
  assert resp.status == 200

  let content_type = echo response.get_header(resp, "content-type")
  assert content_type == Ok("application/json")

  // assert resp.body == "{\"message\":\"Hello World\"}"
  echo resp

  user_from_json(resp.body) |> result.map_error(json_error_to_string)
}

pub fn main() -> Nil {
  {
    use token <- result.try(get_token())
    use user <- result.try(get_me(token))
    Ok(Nil)
  }
  Nil
}
