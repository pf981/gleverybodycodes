import gleam/io
import internal/get
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

  let input = get.get_input(1, 1, 1)
  case input {
    Ok(s) -> io.println(s)
    Error(e) -> e |> snag.pretty_print() |> io.println_error()
  }
  Nil
}
