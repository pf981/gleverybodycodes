import envoy
import gleam/bool
import gleam/io
import gleam/result
import simplifile

// envoy.get("EC_CONFIG_DIR")
// envoy.get("EC_DATA_DIR")
fn get_token() -> Result(String, simplifile.FileError) {
  use _ <- result.try_recover(envoy.get("EC_TOKEN"))

  let path = case envoy.get("EC_CONFIG_DIR") {
    Ok(path) -> path <> "token"
    Error(Nil) -> "~/.config/ecd/token"
  }
  simplifile.read(path)
}

pub fn main() -> Nil {
  io.println("Hello from gleverybodycodes!")

  case get_token() {
    Ok(token) -> io.println(token)
    Error(_) -> io.println("Missing token")
  }
}
