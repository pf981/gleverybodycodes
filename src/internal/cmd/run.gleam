import gleam/dynamic
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/result
import gleam/string
import glint
import internal/get
import internal/package_tools
import snag.{type Result}

pub fn run_command() -> glint.Command(Result(String)) {
  use <- glint.command_help("Run the specified event, quest, and part")
  use <- glint.unnamed_args(glint.EqArgs(3))
  use _, args, _ <- glint.command()

  // TODO: Properly handle this
  let assert [event, quest, part] = args
  let assert Ok(event) = int.parse(event)
  let assert Ok(quest) = int.parse(quest)
  let assert Ok(part) = int.parse(part)

  run(event, quest, part)
  |> result.map(fn(output) {
    "Event "
    <> int.to_string(event)
    <> ", Quest "
    <> int.to_string(quest)
    <> ", Part "
    <> int.to_string(part)
    <> ": "
    <> output
  })
}

fn run(event: Int, quest: Int, part: Int) -> Result(String) {
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
