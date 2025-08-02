import argv
import gleam/int
import gleam/io
import gleam/result
import glint

// import internal/cmd/new
// import internal/cmd/run
import snag

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

fn run_command() -> glint.Command(Result(String, snag.Snag)) {
  // use <- glint.command_help("Prints Hello, <names>!")
  // use <- glint.unnamed_args(glint.MinArgs(1))
  // use _, args, flags <- glint.command()
  // // let assert Ok(caps) = glint.get_flag(flags, caps_flag())
  // // let assert Ok(repeat) = glint.get_flag(flags, repeat_flag())
  // // let assert [name, ..rest] = args
  // Ok("")

  use <- glint.command_help("Run the specified event and quest")
  use <- glint.unnamed_args(glint.EqArgs(0))
  use event <- glint.named_arg("event")
  use quest <- glint.named_arg("quest")
  use named, _unnamed, _flags <- glint.command()

  use event <- result.try(
    int.parse(event(named))
    |> result.replace_error(
      snag.new("Invalid event value '" <> event(named) <> "'")
      |> snag.layer("event must be an integer"),
    ),
  )
  use quest <- result.map(
    int.parse(quest(named))
    |> result.replace_error(
      snag.new("Invalid quest value '" <> quest(named) <> "'")
      |> snag.layer("quest must be an integer"),
    ),
  )

  // TODO: Properly handle this
  // let assert [event, quest] = args
  // let assert Ok(event) = int.parse(event)
  // let assert Ok(quest) = int.parse(quest)

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
  s
  // ""
}
