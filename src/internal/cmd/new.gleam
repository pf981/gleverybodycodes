import filepath
import gleam/int
import gleam/list
import gleam/result
import glint
import internal/package_tools
import simplifile
import snag

pub fn new_command() -> glint.Command(snag.Result(String)) {
  use <- glint.command_help("Create .gleam and input files")
  use <- glint.unnamed_args(glint.EqArgs(2))
  use parse_flag <- glint.flag(
    glint.bool_flag("parse")
    |> glint.flag_default(False)
    |> glint.flag_help("Generate day runners with a parse function"),
  )
  use _, args, flags <- glint.command()

  // TODO: Properly handle this
  let assert Ok(add_parse) = parse_flag(flags)
  let assert [event, quest] = args
  let assert Ok(event) = int.parse(event)
  // How do I do unnamed arg constraints? Does it only apply to flags?
  // |> glint.constraint(constraint.one_of([1, 2, 3]))
  let assert Ok(quest) = int.parse(quest)

  //   use success <- result.map(
  //     new(event, quest, add_parse)
  //     |> snag.map_error(err_to_string),
  //   )
  //   //   |> (fn() {"Created file: " <> )
  new(event, quest, add_parse)
  |> snag.map_error(err_to_string)
  |> result.map(fn(success) { "Created file: " <> success.name })
}

const gleam_starter = "pub fn pt_1(input: String) {
  todo as \"part 1 not implemented\"
}

pub fn pt_2(input: String) {
  todo as \"part 2 not implemented\"
}

pub fn pt_3(input: String) {
  todo as \"part 3 not implemented\"
}
"

const parse_starter = "pub fn parse(input: String) -> String {
  todo as \"parse not implemented\"
}
"

type Success {
  Dir(name: String)
  File(name: String)
}

type Err {
  FailedToCreateDir(String, simplifile.FileError)
  FailedToCreateFile(String, simplifile.FileError)
  FailedToWriteToFile(String, simplifile.FileError)
}

fn new(event: Int, quest: Int, add_parse: Bool) -> Result(Success, Err) {
  // src/event_{event}/quest_{quest}.gleam
  let src_path = gleam_src_path(event, quest)

  use _ <- result.try(create_dir(filepath.directory_name(src_path)))

  use _ <- result.try(
    simplifile.create_file(src_path)
    |> result.map_error(FailedToCreateFile(src_path, _)),
  )

  let file_data = case add_parse {
    True -> parse_starter <> "\n" <> gleam_starter
    False -> gleam_starter
  }

  simplifile.write(src_path, file_data)
  |> result.map_error(FailedToWriteToFile(src_path, _))
  |> result.replace(File(src_path))
}

fn err_to_string(e: Err) -> String {
  case e {
    FailedToCreateDir(d, e) ->
      "failed to create dir '" <> d <> "': " <> simplifile.describe_error(e)
    FailedToCreateFile(f, e) ->
      "failed to create file '" <> f <> "': " <> simplifile.describe_error(e)
    FailedToWriteToFile(f, e) ->
      "failed to write to file '" <> f <> "': " <> simplifile.describe_error(e)
  }
}

fn gleam_src_path(event: Int, quest: Int) -> String {
  list.fold(
    over: [
      "src",
      "event_" <> int.to_string(event),
      "quest_" <> int.to_string(quest) <> ".gleam",
    ],
    from: package_tools.root(),
    with: filepath.join,
  )
}

fn create_dir(dir: String) -> Result(Success, Err) {
  simplifile.create_directory_all(dir)
  |> handle_dir_open_res(dir)
  |> result.map(Dir)
}

fn handle_dir_open_res(
  res: Result(_, simplifile.FileError),
  filename: String,
) -> Result(String, Err) {
  case res {
    Ok(_) -> Ok(filename)
    Error(simplifile.Eexist) -> Ok("")
    Error(e) -> Error(FailedToCreateDir(filename, e))
  }
}
