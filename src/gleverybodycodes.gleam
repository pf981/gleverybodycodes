import argv
import gleam/io
import glint
import internal/cmd/new
import internal/cmd/run
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
  // $ gleam run event quest
  // 
  // Submit the result for the event and quest
  // Will first check if the account has solved this quest
  // Will only submit if
  //   - This submission value doesn't match cached previously submitted values
  //   - The part runs successfully (doesn't panic)
  //   - The account has completed previous prerequisite quest parts
  // $ gleam run --submit=part event quest

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
    |> glint.add(at: ["new"], do: new.new_command())
    |> glint.add(at: ["run"], do: run.run_command())

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
