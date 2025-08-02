import gleam/dynamic
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/result
import gleam/string
import internal/get
import internal/package_tools
import snag.{type Result}

pub fn run_part(event: Int, quest: Int, part: Int) -> Result(String) {
  let module_name =
    "event_" <> int.to_string(event) <> "/quest_" <> int.to_string(quest)
  let function_name = "pt_" <> int.to_string(part)

  let assert Ok(package) = package_tools.get_package_interface()
  let assert Ok(func) =
    package_tools.get_function(package, module_name, function_name)

  use input <- result.try(get.get_input(event, quest, part))

  let output = func.f(dynamic.string(input))

  let decoder =
    decode.one_of(decode.string, or: [
      decode.int |> decode.map(int.to_string),
      decode.float |> decode.map(float.to_string),
    ])

  decode.run(output, decoder)
  |> snag.map_error(string.inspect)
  |> snag.context(
    "Couldn't decode output of " <> module_name <> "." <> function_name,
  )
}
