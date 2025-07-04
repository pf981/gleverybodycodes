import aes
import envoy
import gleam
import gleam/bool
import gleam/dynamic/decode
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleam/option.{type Option, None}
import gleam/result
import gleam/string
import simplifile
import snag.{type Result}

fn get_home() -> Result(String) {
  case envoy.get("HOME") {
    Ok(home) -> Ok(home)
    Error(Nil) ->
      envoy.get("USERPROFILE")
      |> snag.map_error(fn(_) { "Unable to expand ~" })
      |> snag.context("Set environment variables $HOME or $USERPROFILE.")
  }
}

fn expand_home(path: String) -> Result(String) {
  use <- bool.guard(!string.contains(path, "~"), Ok(path))
  use home <- result.try(get_home())
  path |> string.replace("~", home) |> Ok()
}

// EC_CONFIG_DIR, EC_DATA_DIR, EC_TOKEN
fn get_token() -> Result(String) {
  use _ <- result.try_recover(envoy.get("EC_TOKEN"))

  use path <- result.try(
    envoy.get("EC_CONFIG_DIR")
    |> result.unwrap("~/.config/ecd/token")
    |> expand_home(),
  )

  simplifile.read(path)
  |> result.map(string.trim_end)
  |> snag.map_error(fn(e) {
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

fn user_from_json(json_string: String) -> gleam.Result(User, json.DecodeError) {
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

fn get_json(token: String, url: String) -> Result(String) {
  let assert Ok(base_req) = request.to(url)

  let req =
    base_req
    |> request.prepend_header("accept", "application/json")
    |> request.prepend_header("User-Agent", "github.com/pf981/gleverybodycodes")
    |> request.prepend_header("Cookie", "everybody-codes=" <> token)

  use resp <- result.try(
    httpc.send(req) |> snag.map_error(http_error_to_string),
  )
  case resp.status {
    200 -> Ok(resp.body)
    error_status ->
      snag.error(
        "Non-200 status, " <> int.to_string(error_status) <> ", from " <> url,
      )
  }
}

fn get_me(token: String) -> Result(User) {
  use json <- result.try(get_json(token, "https://everybody.codes/api/user/me"))
  user_from_json(json) |> snag.map_error(json_error_to_string)
}

type Inputs =
  #(String, String, String)

fn inputs_from_json(
  json_string: String,
) -> gleam.Result(Inputs, json.DecodeError) {
  let input_decoder = {
    use input1 <- decode.field("1", decode.string)
    use input2 <- decode.field("1", decode.string)
    use input3 <- decode.field("1", decode.string)
    decode.success(#(input1, input2, input3))
  }
  json.parse(from: json_string, using: input_decoder)
}

fn get_inputs(
  token: String,
  seed: Int,
  event: Int,
  quest: Int,
) -> Result(Inputs) {
  use json <- result.try(get_json(
    token,
    "https://everybody-codes.b-cdn.net/assets/"
      <> int.to_string(event)
      <> "/"
      <> int.to_string(quest)
      <> "/input/"
      <> int.to_string(seed)
      <> ".json",
  ))
  inputs_from_json(json) |> snag.map_error(json_error_to_string)
}

type Aes {
  ZeroComplete(key1: String)
  OneComplete(key1: String, answer1: String, key2: String)
  TwoComplete(
    key1: String,
    answer1: String,
    key2: String,
    answer2: String,
    key3: String,
  )
  ThreeComplete(
    key1: String,
    answer1: String,
    key2: String,
    answer2: String,
    key3: String,
    answer3: String,
  )
}

fn aes_from_json(json_string: String) -> gleam.Result(Aes, json.DecodeError) {
  let aes0_decoder = {
    use key1 <- decode.field("key1", decode.string)
    decode.success(ZeroComplete(key1:))
  }
  let aes1_decoder = {
    use key1 <- decode.field("key1", decode.string)
    use key2 <- decode.field("key2", decode.string)
    use answer1 <- decode.field("answer1", decode.string)
    decode.success(OneComplete(key1:, answer1:, key2:))
  }
  let aes2_decoder = {
    use key1 <- decode.field("key1", decode.string)
    use key2 <- decode.field("key2", decode.string)
    use key3 <- decode.field("key2", decode.string)
    use answer1 <- decode.field("answer1", decode.string)
    use answer2 <- decode.field("answer1", decode.string)
    decode.success(TwoComplete(key1:, answer1:, key2:, answer2:, key3:))
  }
  let aes3_decoder = {
    use key1 <- decode.field("key1", decode.string)
    use key2 <- decode.field("key2", decode.string)
    use key3 <- decode.field("key2", decode.string)
    use answer1 <- decode.field("answer1", decode.string)
    use answer2 <- decode.field("answer1", decode.string)
    use answer3 <- decode.field("answer1", decode.string)
    decode.success(ThreeComplete(
      key1:,
      answer1:,
      key2:,
      answer2:,
      key3:,
      answer3:,
    ))
  }
  json.parse(
    from: json_string,
    using: decode.one_of(aes3_decoder, [
      aes2_decoder,
      aes1_decoder,
      aes0_decoder,
    ]),
  )
}

fn get_aes(token: String, event: Int, quest: Int) -> Result(Aes) {
  use json <- result.try(get_json(
    token,
    "https://everybody.codes/api/event/"
      <> int.to_string(event)
      <> "/quest/"
      <> int.to_string(quest),
  ))
  aes_from_json(json) |> snag.map_error(json_error_to_string)
}

fn get_input(event: Int, quest: Int, part: Int) -> Result(String) {
  use token <- result.try(get_token())
  use user <- result.try(get_me(token))
  let seed = user.seed
  use inputs <- result.try(get_inputs(token, seed, event, quest))
  use aes_keys <- result.try(get_aes(token, event, quest))

  use #(key, input) <- result.try(
    case part, aes_keys {
      1, aes_keys -> Ok(#(aes_keys.key1, inputs.0))
      2, OneComplete(key2:, ..)
      | 2, TwoComplete(key2:, ..)
      | 2, ThreeComplete(key2:, ..)
      -> Ok(#(key2, inputs.1))
      3, TwoComplete(key3:, ..) | 3, ThreeComplete(key3:, ..) ->
        Ok(#(key3, inputs.2))
      2, _ | 3, _ ->
        snag.error(
          "Havn't completed prerequisite parts to get part "
          <> int.to_string(part),
        )
      _, _ -> snag.error("Invalid part: " <> int.to_string(part))
    }
    |> snag.context(
      "Getting input event="
      <> int.to_string(event)
      <> ", quest="
      <> int.to_string(quest)
      <> ", part="
      <> int.to_string(part),
    ),
  )

  aes.decrypt_aes_256_cbc(key, input)
  |> snag.map_error(aes.aes_error_to_string)
}

pub fn main() -> Nil {
  // let res = {
  //   use token <- result.try(get_token())
  //   use user <- result.try(get_me(token))
  //   let seed = user.seed
  //   use inputs <- result.try(get_inputs(token, seed, 1, 1))
  //   use aes <- result.try(get_aes(token, 1, 1))
  //   echo user
  //   echo inputs
  //   echo aes
  //   Ok(Nil)
  // }

  let input = get_input(1, 1, 1)
  case input {
    Ok(s) -> io.println(s)
    Error(e) -> e |> snag.pretty_print() |> io.println_error()
  }
  Nil
}
