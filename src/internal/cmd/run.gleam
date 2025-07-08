// import decode
import filepath
import gleam/dynamic/decode
import gleam/float
import internal/package_tools

// import gladvent/internal/cmd.{Ending, Endless}
// import gladvent/internal/input
// import gladvent/internal/parse.{type Day}
// import gladvent/internal/runners
// import gladvent/internal/util
import gleam
import gleam/dict
import gleam/dynamic.{type Dynamic}

// import gleam/erlang
import gleam/erlang/atom
import gleam/erlang/charlist.{type Charlist}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/package_interface
import gleam/result
import gleam/string
import glint
import simplifile
import snag.{type Result, type Snag}
import spinner

// import tom

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
  //   |> snag.map_error(err_to_string)
}

fn run(event: Int, quest: Int, part: Int) -> Result(String) {
  let module_name =
    "event_" <> int.to_string(event) <> "/quest_" <> int.to_string(quest)
  let function_name = "pt_" <> int.to_string(part)

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

  decode.run(result, decoder)
  |> snag.map_error(string.inspect)
  |> snag.context(
    "Couldn't decode result of " <> module_name <> "." <> function_name,
  )
}
