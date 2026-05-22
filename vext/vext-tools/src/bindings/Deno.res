// SPDX-License-Identifier: MPL-2.0
// ReScript bindings for Deno runtime APIs

// Deno.Command for executing commands
module Command = {
  type t

  type commandOptions = {
    args: array<string>,
    stdout: string,
    stderr: string,
  }

  type output = {
    success: bool,
    stdout: Js.TypedArray2.Uint8Array.t,
    stderr: Js.TypedArray2.Uint8Array.t,
  }

  @new @module("Deno") external make: (string, commandOptions) => t = "Command"
  @send external output: t => promise<output> = "output"
}

// Deno.connect for network connections
module Net = {
  type conn

  type connectOptions = {
    hostname: string,
    port: int,
  }

  @module("Deno") external connect: connectOptions => promise<conn> = "connect"
  @send external write: (conn, Js.TypedArray2.Uint8Array.t) => promise<int> = "write"
  @send external close: conn => unit = "close"
}

// Deno.stdin
module Stdin = {
  type t

  @module("Deno") @val external stdin: t = "stdin"
  @send external read: (t, Js.TypedArray2.Uint8Array.t) => promise<Js.Nullable.t<int>> = "read"
}

// Deno.env
module Env = {
  @module("Deno") @scope("env") external get: string => option<string> = "get"
}

// Deno.args
@module("Deno") @val external args: array<string> = "args"

// Deno.exit
@module("Deno") external exit: int => unit = "exit"

// Deno file operations
@module("Deno") external stat: string => promise<{..}> = "stat"
@module("Deno") external writeTextFile: (string, string) => promise<unit> = "writeTextFile"
@module("Deno") external chmod: (string, int) => promise<unit> = "chmod"

// TextEncoder/TextDecoder
module TextEncoder = {
  type t

  @new external make: unit => t = "TextEncoder"
  @send external encode: (t, string) => Js.TypedArray2.Uint8Array.t = "encode"
}

module TextDecoder = {
  type t

  @new external make: unit => t = "TextDecoder"
  @send external decode: (t, Js.TypedArray2.Uint8Array.t) => string = "decode"
}

// Console
module Console = {
  @val external log: string => unit = "console.log"
  @val external error: string => unit = "console.error"
}
