import envoy
import gleam
import gleam/bool
import gleam/dynamic
import gleam/dynamic/decode
import gleam/float
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import internal/aes
import internal/package_tools
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
  "Unable to parse JSON: " <> string.inspect(error)
}

fn http_error_to_string(error: httpc.HttpError) -> String {
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

type Keys {
  Keys(
    key1: String,
    key2: Option(String),
    key3: Option(String),
    answer1: Option(String),
    answer2: Option(String),
    answer3: Option(String),
  )
}

fn keys_from_json(json_string: String) -> gleam.Result(Keys, json.DecodeError) {
  let keys_decoder = {
    use key1 <- decode.field("key1", decode.string)
    use key2 <- decode.optional_field(
      "key2",
      None,
      decode.optional(decode.string),
    )
    use key3 <- decode.optional_field(
      "key3",
      None,
      decode.optional(decode.string),
    )
    use answer1 <- decode.optional_field(
      "answer1",
      None,
      decode.optional(decode.string),
    )
    use answer2 <- decode.optional_field(
      "answer2",
      None,
      decode.optional(decode.string),
    )
    use answer3 <- decode.optional_field(
      "answer3",
      None,
      decode.optional(decode.string),
    )
    decode.success(Keys(key1:, key2:, key3:, answer1:, answer2:, answer3:))
  }
  json.parse(from: json_string, using: keys_decoder)
}

fn get_keys(token: String, event: Int, quest: Int) -> Result(Keys) {
  use json <- result.try(get_json(
    token,
    "https://everybody.codes/api/event/"
      <> int.to_string(event)
      <> "/quest/"
      <> int.to_string(quest),
  ))
  keys_from_json(json) |> snag.map_error(json_error_to_string)
}

// TODO:
// Cache:
//  - get_token()
//  - get_me()
//  - download_me(token)
//  - get_seed()
//  - get_input(event, quest, part)
//  - download_inputs(token, seed, event, quest)
//  - get_key(event, quest, part)
//  - download_keys(token, event, quest)
//
// Can I just use string.inspect to convert error messages?
// |> result.map_error(fn(e) {
//   string.inspect(e)
//   |> snag.new
//   |> snag.layer("failed to read gleam.toml")
// })
pub fn get_input(event: Int, quest: Int, part: Int) -> Result(String) {
  use token <- result.try(get_token())
  use user <- result.try(get_me(token))
  let seed = user.seed
  use inputs <- result.try(get_inputs(token, seed, event, quest))
  use keys <- result.try(get_keys(token, event, quest))

  use #(key, input) <- result.try(
    case part, keys {
      1, Keys(key1:, ..) -> Ok(#(key1, inputs.0))
      2, Keys(key2: Some(key2), ..) -> Ok(#(key2, inputs.0))
      3, Keys(key3: Some(key3), ..) -> Ok(#(key3, inputs.0))
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

  // let input = get.get_input(1, 1, 1)
  // case input {
  //   Ok(s) -> io.println(s)
  //   Error(e) -> e |> snag.pretty_print() |> io.println_error()
  // }

  let #(event, quest) = #(1, 1)
  let module_name =
    "event_" <> int.to_string(event) <> "/quest_" <> int.to_string(quest)
  let function_name = "pt_1"

  // use module <- result.try(
  //   dict.get(package.modules, module_name)
  //   |> result.replace_error(ModuleNotFound(module_name)),
  // )
  // let _ = {
  //   use package <- result.try(package_tools.get_package_interface())

  //   case package_tools.get_function(package:, module_name:, function_name:) {
  //     Error(_) -> todo
  //     Ok(Func(f:, info:)) -> todo
  //   }
  // }
  let assert Ok(package) = package_tools.get_package_interface()
  let assert Ok(func) =
    package_tools.get_function(package, module_name, function_name)
  echo func.f
  echo func.info

  let result = func.f(dynamic.string("Hello World!"))

  let decoder =
    decode.one_of(decode.string, or: [
      decode.int |> decode.map(int.to_string),
      decode.float |> decode.map(float.to_string),
    ])
  echo decode.run(result, decoder)
  // let result = case func.f(dynamic.string("Hello World!")) {
  //   dynamic
  // }
  Nil
}
