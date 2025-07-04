import gleam/bit_array
import gleam/bool
import gleam/result
import gleam/string

pub type AesError {
  DecryptionFailed
  InvalidPadding
}

pub fn aes_error_to_string(error: AesError) {
  case error {
    DecryptionFailed -> "Decryption failed"
    InvalidPadding -> "Invalid padding"
  }
}

pub fn decrypt_aes_256_cbc(
  key_string: String,
  ciphertext_hex: String,
) -> Result(String, AesError) {
  let key = bit_array.from_string(key_string)
  let iv = key_string |> string.slice(0, 16) |> bit_array.from_string()

  use ciphertext <- result.try(
    bit_array.base16_decode(ciphertext_hex)
    |> result.replace_error(DecryptionFailed),
  )

  use unpadded <- result.try(
    crypto_one_time_raw(aes_256_cbc(), key, iv, ciphertext, False)
    |> unpad(16),
  )
  unpadded
  |> bit_array.to_string
  |> result.replace_error(DecryptionFailed)
}

@external(erlang, "crypto", "crypto_one_time")
fn crypto_one_time_raw(
  cipher: atom,
  key: BitArray,
  iv: BitArray,
  data: BitArray,
  encrypt: Bool,
) -> BitArray

@external(erlang, "erlang", "list_to_atom")
fn list_to_atom(charlist: List(Int)) -> atom

@external(erlang, "erlang", "binary_to_list")
fn binary_to_list(binary: BitArray) -> List(Int)

fn aes_256_cbc() -> atom {
  bit_array.from_string("aes_256_cbc")
  |> binary_to_list
  |> list_to_atom
}

fn unpad(bits: BitArray, block_size: Int) -> Result(BitArray, AesError) {
  use padding <- result.try(
    case bit_array.slice(bits, bit_array.byte_size(bits) - 1, 1) {
      Ok(<<value:int>>) -> Ok(value)
      _ -> Error(InvalidPadding)
    },
  )

  use <- bool.guard(padding > block_size, Error(InvalidPadding))

  case bit_array.slice(bits, 0, bit_array.byte_size(bits) - padding) {
    Ok(unpadded) -> Ok(unpadded)
    Error(_) -> Error(InvalidPadding)
  }
}
