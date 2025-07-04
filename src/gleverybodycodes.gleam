import envoy
import filepath
import gleam/io
import gleam/result
import gleam/string
import simplifile

fn get_home() -> Result(String, Nil) {
  use _ <- result.try_recover(envoy.get("HOME"))
  envoy.get("USERPROFILE")
}

fn expand_home(path: String) -> Result(String, Nil) {
  case path |> string.contains("~") {
    True -> {
      case get_home() {
        Ok(home) -> Ok(path |> string.replace("~", home))
        Error(e) -> Error(e)
      }
    }
    False -> Ok(path)
  }
}

// envoy.get("EC_CONFIG_DIR")
// envoy.get("EC_DATA_DIR")
fn get_token() -> Result(String, simplifile.FileError) {
  use _ <- result.try_recover(envoy.get("EC_TOKEN"))

  let path =
    result.unwrap(envoy.get("EC_CONFIG_DIR"), "~/.config/ecd/token")
    |> expand_home()

  use path <- result.try(
    path |> result.replace_error(simplifile.Unknown("Unable to expand ~")),
  )
  simplifile.read(path) |> result.map(string.trim_end)
}

pub fn main() -> Nil {
  io.println("Hello from gleverybodycodes!")

  case get_token() {
    Ok(token) -> io.println(token)
    Error(_) -> io.println("Missing token")
  }
}
