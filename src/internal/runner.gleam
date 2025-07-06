import gleam/bool
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom
import gleam/int
import gleam/list
import gleam/package_interface
import gleam/result
import gleam/string

pub type RunnerRetrievalErr {
  ModuleNotFound(String)
  ParseFunctionInvalid(String)
  FunctionNotFound(module: String, function: String)
  IncorrectInputParameters(
    function: String,
    expected: String,
    got: List(package_interface.Type),
  )
}

fn retrieve_runner(
  module_name: String,
  module: package_interface.Module,
  function_name: String,
  runner_param_type: package_interface.Type,
) -> Result(fn(Dynamic) -> Dynamic, RunnerRetrievalErr) {
  use f <- result.try(
    module.functions
    |> dict.get(function_name)
    |> result.replace_error(FunctionNotFound(module_name, function_name)),
  )
  use <- bool.guard(
    when: case f.parameters {
      [param] -> param.type_ != runner_param_type
      _ -> True
    },
    return: Error(IncorrectInputParameters(
      function: function_name,
      expected: type_to_string(runner_param_type),
      got: list.map(f.parameters, fn(p) { p.type_ }),
    )),
  )

  Ok(function_arity_one(
    atom.create(to_erlang_module_name(module_name)),
    atom.create(function_name),
  ))
}

fn to_erlang_module_name(name) {
  string.replace(name, "/", "@")
}

@external(erlang, "runner_ffi", "function_arity_one")
fn function_arity_one(
  module: atom.Atom,
  function: atom.Atom,
) -> fn(Dynamic) -> Dynamic

fn parse_function(module: String) -> fn(String) -> Dynamic {
  do_parse_function(atom.create(to_erlang_module_name(module)))
}

@external(erlang, "runner_ffi", "parse_function")
fn do_parse_function(module: atom.Atom) -> fn(String) -> Dynamic

fn type_to_string(t: package_interface.Type) -> String {
  case t {
    package_interface.Tuple(elements: elements) ->
      "#(" <> type_list_to_string(elements) <> ")"
    package_interface.Fn(parameters: parameters, return: return) ->
      "fn("
      <> type_list_to_string(parameters)
      <> ") -> "
      <> type_to_string(return)
    package_interface.Variable(id: id) -> int.to_string(id)
    package_interface.Named(
      name: name,
      package: _,
      module: module,
      parameters: parameters,
    ) ->
      case parameters {
        [] -> module <> "." <> name
        _ ->
          module <> "." <> name <> "(" <> type_list_to_string(parameters) <> ")"
      }
  }
}

fn type_list_to_string(lt: List(package_interface.Type)) -> String {
  lt
  |> list.map(type_to_string)
  |> string.join(", ")
}
