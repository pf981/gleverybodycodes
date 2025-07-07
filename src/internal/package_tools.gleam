import filepath
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom
import gleam/int
import gleam/json
import gleam/list
import gleam/package_interface
import gleam/result
import gleam/string
import internal/util
import shellout
import simplifile
import snag
import spinner

const package_interface_path = "build/.gladvent/pkg.json"

pub type Func {
  Func(f: fn(Dynamic) -> Dynamic, info: package_interface.Function)
}

pub type FunctionRetrievalErr {
  ModuleNotFound(String)
  ParseFunctionInvalid(String)
  FunctionNotFound(module: String, function: String)
  IncorrectInputParameters(
    function: String,
    expected: String,
    got: List(package_interface.Type),
  )
}

pub type PackageInterfaceError {
  FailedToGleamBuild(String)
  FailedToGeneratePackageInterface(String)
  FailedToReadPackageInterface(simplifile.FileError)
  FailedToDecodePackageInterface(json.DecodeError)
}

pub fn root() -> String {
  find_root(".")
}

pub fn get_function(
  package: package_interface.Package,
  module_name: String,
  function_name: String,
) -> Result(Func, FunctionRetrievalErr) {
  use module <- result.try(
    dict.get(package.modules, module_name)
    |> result.replace_error(ModuleNotFound(module_name)),
  )
  use package_interface_function <- result.try(
    module.functions
    |> dict.get(function_name)
    |> result.replace_error(FunctionNotFound(module_name, function_name)),
  )

  let func =
    function_arity_one(
      atom.create(to_erlang_module_name(module_name)),
      atom.create(function_name),
    )
  Ok(Func(func, package_interface_function))
}

pub fn package_interface_error_to_snag(e: PackageInterfaceError) -> snag.Snag {
  case e {
    FailedToGleamBuild(s) ->
      snag.new(s)
      |> snag.layer("failed to build gleam project")
    FailedToGeneratePackageInterface(s) ->
      snag.new(s)
      |> snag.layer("failed to generate " <> package_interface_path)
    FailedToReadPackageInterface(e) ->
      snag.new(string.inspect(e))
      |> snag.layer("failed to read " <> package_interface_path)
    FailedToDecodePackageInterface(e) ->
      snag.new(string.inspect(e))
      |> snag.layer("failed to decode package interface json")
  }
}

pub fn get_package_interface() -> Result(
  package_interface.Package,
  PackageInterfaceError,
) {
  // use <- snagify_error(with: package_interface_error_to_snag)
  let spinner =
    spinner.new("initializing package interface")
    |> spinner.start()

  use <- util.defer(do: fn() { spinner.stop(spinner) })

  let root = root()

  spinner.set_text(spinner, "rebuilding project")
  use _ <- result.try(
    shellout.command("gleam", ["build"], root, [])
    |> result.map_error(fn(e) { FailedToGeneratePackageInterface(e.1) }),
  )

  spinner.set_text(spinner, "generating package interface file")
  use _ <- result.try(
    shellout.command(
      "gleam",
      ["export", "package-interface", "--out", package_interface_path],
      root,
      [],
    )
    |> result.map_error(fn(e) { FailedToGeneratePackageInterface(e.1) }),
  )

  spinner.set_text(spinner, "reading " <> package_interface_path)
  use pkg_interface_contents <- result.try(
    simplifile.read(filepath.join(root, package_interface_path))
    |> result.map_error(FailedToReadPackageInterface),
  )

  spinner.set_text(spinner, "decoding package interface JSON")
  use pkg_interface_details <- result.try(
    json.parse(from: pkg_interface_contents, using: package_interface.decoder())
    |> result.map_error(FailedToDecodePackageInterface),
  )

  Ok(pkg_interface_details)
}

// fn retrieve_runner(
//   module_name: String,
//   module: package_interface.Module,
//   function_name: String,
//   runner_param_type: package_interface.Type,
// ) -> Result(fn(Dynamic) -> Dynamic, RunnerRetrievalErr) {
//   use f <- result.try(
//     module.functions
//     |> dict.get(function_name)
//     |> result.replace_error(FunctionNotFound(module_name, function_name)),
//   )
//   use <- bool.guard(
//     when: case f.parameters {
//       [param] -> param.type_ != runner_param_type
//       _ -> True
//     },
//     return: Error(IncorrectInputParameters(
//       function: function_name,
//       expected: type_to_string(runner_param_type),
//       got: list.map(f.parameters, fn(p) { p.type_ }),
//     )),
//   )

//   Ok(function_arity_one(
//     atom.create(to_erlang_module_name(module_name)),
//     atom.create(function_name),
//   ))
// }

fn find_root(path: String) -> String {
  let toml = filepath.join(path, "gleam.toml")

  case simplifile.is_file(toml) {
    Ok(False) | Error(_) -> find_root(filepath.join("..", path))
    Ok(True) -> path
  }
}

fn to_erlang_module_name(name) {
  string.replace(name, "/", "@")
}

@external(erlang, "package_tools_ffi", "function_arity_one")
fn function_arity_one(
  module: atom.Atom,
  function: atom.Atom,
) -> fn(Dynamic) -> Dynamic

fn parse_function(module: String) -> fn(String) -> Dynamic {
  do_parse_function(atom.create(to_erlang_module_name(module)))
}

@external(erlang, "package_tools_ffi", "parse_function")
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
