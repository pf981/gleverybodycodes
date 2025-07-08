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
  // gleam run new event quest
  // gleam run run event quest [part]
  // gleam run submit event quest part
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
