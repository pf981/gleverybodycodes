import gleam/bit_array
import gleam/result
import gleam/string

@external(erlang, "crypto", "crypto_one_time")
fn crypto_one_time_raw(
  cipher: atom,
  key: BitArray,
  iv: BitArray,
  data: BitArray,
  encrypt: Bool,
) -> Result(BitArray, atom)

// Create atoms using Erlang's list_to_atom function
@external(erlang, "erlang", "list_to_atom")
fn list_to_atom(charlist: List(Int)) -> atom

// Helper to convert string to charlist
@external(erlang, "erlang", "binary_to_list")
fn binary_to_list(binary: BitArray) -> List(Int)

fn aes_256_cbc() -> atom {
  bit_array.from_string("aes_256_cbc")
  |> binary_to_list
  |> list_to_atom
}

pub fn dec(key_string: String, ciphertext_hex: String) {
  let key = bit_array.from_string(key_string)
  let iv = key_string |> string.slice(0, 16) |> bit_array.from_string()
  let assert Ok(ciphertext) = bit_array.base16_decode(ciphertext_hex)
  crypto_one_time_raw(aes_256_cbc(), key, iv, ciphertext, False)
}
