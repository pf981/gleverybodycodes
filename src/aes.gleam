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
) -> BitArray

//-> Result(BitArray, atom)

@external(erlang, "erlang", "list_to_atom")
fn list_to_atom(charlist: List(Int)) -> atom

@external(erlang, "erlang", "binary_to_list")
fn binary_to_list(binary: BitArray) -> List(Int)

fn aes_256_cbc() -> atom {
  bit_array.from_string("aes_256_cbc")
  |> binary_to_list
  |> list_to_atom
}

fn unpad(bits: BitArray, block_size: Int) {
  let assert Ok(padding) =
    bit_array.slice(bits, bit_array.byte_size(bits) - 1, 1)
  let padding = bit_array_to_int(padding)
  let assert Ok(result) =
    bit_array.slice(bits, 0, bit_array.byte_size(bits) - padding)
  result
}

fn bit_array_to_int(bits: BitArray) -> Int {
  case bits {
    <<value:int>> -> value
    _ -> panic
  }
}

pub fn decrypt_aes_256_cbc(
  key_string: String,
  ciphertext_hex: String,
) -> Result(String, Nil) {
  let key = bit_array.from_string(key_string)
  let iv = key_string |> string.slice(0, 16) |> bit_array.from_string()
  let assert Ok(ciphertext) = bit_array.base16_decode(ciphertext_hex)
  let result = crypto_one_time_raw(aes_256_cbc(), key, iv, ciphertext, False)
  result |> unpad(16) |> bit_array.to_string
}
