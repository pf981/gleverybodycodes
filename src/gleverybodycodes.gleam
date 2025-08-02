import argv
import gleam/bool
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import glint
import glint/constraint
import internal/cmd/new
import snag.{type Result}

/// Add this function to your project's `main` function in order to run the gladvent CLI.
///
/// This function gets its input from the command line arguments by using the `argv` library.
///
pub fn run() -> Nil {
  // Run all parts for an event and quest
  // If the gleam file for the quest does not exist, it will be created
  // If the input files do not exist, they will be fetched
  // If the correct result was previously submitted and cached, it will check if the value is correct
  // $ gleam run <event> <quest>
  // 
  // Submit the result for the event and quest
  // Will first check if the account has solved this quest
  // Will only submit if
  //   - This submission value doesn't match cached previously submitted values
  //   - The part runs successfully (doesn't panic)
  //   - The account has completed previous prerequisite quest parts
  // $ gleam run --submit=<part> <event> <quest>

  // Thoughts: How to force it to check all solutions?
  let commands =
    glint.new()
    |> glint.path_help(
      [],
      "gleverybodycodes is an Everybody Codes runner and generator for gleam.


      Please use either the 'run' or 'new' commands.
      ",
    )
    |> glint.pretty_help(glint.default_pretty_help())
    |> glint.add(at: [], do: run_command())

  use out <- glint.run_and_handle(commands, argv.load().arguments)
  case out {
    Ok(output) -> io.println(output)
    Error(err) -> print_snag_and_halt(err)
  }
}

pub fn main() -> Nil {
  run()
}

@external(erlang, "erlang", "halt")
fn exit(a: Int) -> Nil

fn print_snag_and_halt(err: snag.Snag) -> Nil {
  err
  |> snag.pretty_print()
  |> io.println()
  exit(1)
}

fn submit_flag() {
  glint.int_flag("submit")
  |> glint.flag_help("Submit the <part>. Must be one of <parts>.")
  |> glint.flag_constraint(constraint.one_of([1, 2, 3]))
}

fn parts_flag() {
  glint.ints_flag("parts")
  |> glint.flag_help("Run the specified <parts>")
  |> glint.flag_default([1, 2, 3])
  |> glint.flag_constraint([1, 2, 3] |> constraint.one_of() |> constraint.each)
}

fn new_flag() {
  glint.bool_flag("new")
  |> glint.flag_help(
    "Create src/event_<event>/quest_<quest>.gleam if it does not exist and do not execute. Cannot be used with --parts or --submit",
  )
  |> glint.flag_default(False)
}

fn run_command() -> glint.Command(Result(String)) {
  use <- glint.command_help("Run the specified <event> and <quest>")
  use <- glint.unnamed_args(glint.EqArgs(0))
  use event <- glint.named_arg("event")
  use quest <- glint.named_arg("quest")

  use submit <- glint.flag(submit_flag())
  use parts <- glint.flag(parts_flag())
  use new <- glint.flag(new_flag())

  use named, _unnamed, flags <- glint.command()

  let assert Ok(parts) = parts(flags)
  let assert Ok(new) = new(flags)

  use event <- result.try(
    int.parse(event(named))
    |> result.replace_error(
      snag.new("Invalid event value '" <> event(named) <> "'")
      |> snag.layer("event must be an integer"),
    ),
  )
  use quest <- result.try(
    int.parse(quest(named))
    |> result.replace_error(
      snag.new("Invalid quest value '" <> quest(named) <> "'")
      |> snag.layer("quest must be an integer"),
    ),
  )

  use <- bool.lazy_guard(new, fn() {
    use <- bool.guard(
      list.length(parts) != 3,
      snag.error("--parts flag cannot be specified when using --new")
        |> snag.context("Invalid arguments"),
    )
    use <- bool.guard(
      result.is_ok(submit(flags)),
      snag.error("--submit flag cannot be specified when using --new")
        |> snag.context("Invalid arguments"),
    )
    case new.new(event, quest, True) {
      Ok(new.Dir(name)) | Ok(new.File(name)) ->
        Ok("Successfully created " <> name)
      Error(e) -> Error(e) |> snag.map_error(new.err_to_string)
    }
    // Ok("")
    // ""
  })

  // case new {
  //   True -> todo
  //   False -> todo
  // }

  case submit(flags) {
    Ok(part) -> io.print("Submit " <> int.to_string(part))
    Error(e) -> io.print("Not submitting")
  }

  // run(event, quest, part)
  // |> result.map(fn(output) {
  //   "Event "
  //   <> int.to_string(event)
  //   <> ", Quest "
  //   <> int.to_string(quest)
  //   <> ", Part "
  //   <> int.to_string(part)
  //   <> ": "
  //   <> output
  // })
  // let s = int.to_string(event()) <> " " <> int.to_string(quest)
  let s = int.to_string(event) <> " " <> int.to_string(quest)
  // // Ok(s)
  Ok(s)
  // ""
}
