import gleam/dynamic
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/io
import gleam/result
import internal/get
import internal/package_tools.{type Func}
import snag

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
