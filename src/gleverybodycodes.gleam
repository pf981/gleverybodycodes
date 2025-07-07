import argv
import gleam/io
import gleam/string
import glint

// import internal/cmd
// import internal/cmd/new
// import internal/cmd/run
import snag

/// Add this function to your project's `main` function in order to run the gladvent CLI.
///
/// This function gets its input from the command line arguments by using the `argv` library.
///
pub fn run() -> Nil {
  let commands =
    glint.new()
    |> glint.path_help(
      [],
      "gleverybodycodes is an Everybody Codes runner and generator for gleam.


      Please use either the 'run' or 'new' commands.
      ",
    )
    |> glint.pretty_help(glint.default_pretty_help())
  // |> glint.group_flag(at: [], of: cmd.year_flag())
  // |> glint.add(at: ["new"], do: new.new_command())
  // |> glint.group_flag(at: ["run"], of: run.timeout_flag())
  // |> glint.group_flag(at: ["run"], of: run.allow_crash_flag())
  // |> glint.group_flag(at: ["run"], of: run.timed_flag())
  // |> glint.add(at: ["run"], do: run.run_command())
  // |> glint.add(at: ["run", "all"], do: run.run_all_command())

  use out <- glint.run_and_handle(commands, argv.load().arguments)
  case out {
    Ok(out) ->
      out
      |> string.join("\n\n")
      |> io.println
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
