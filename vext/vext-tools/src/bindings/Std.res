// SPDX-License-Identifier: MPL-2.0
// ReScript bindings for Deno standard library (@std/*)

// @std/cli/parse-args
module ParseArgs = {
  type parseArgsOptions = {
    string: array<string>,
    boolean: array<string>,
    alias: Js.Dict.t<string>,
  }

  type args = {
    _: array<string>,
  }

  @module("@std/cli/parse-args")
  external parseArgs: (array<string>, parseArgsOptions) => args = "parseArgs"

  // Helper to get string value from parsed args
  let getString: (args, string) => option<string> = (args, key) => {
    let obj = args->Obj.magic
    Js.Dict.get(obj, key)
  }

  // Helper to get bool value from parsed args
  let getBool: (args, string) => bool = (args, key) => {
    let obj: Js.Dict.t<bool> = args->Obj.magic
    Js.Dict.get(obj, key)->Option.getOr(false)
  }
}

// @std/fs
module Fs = {
  @module("@std/fs") external ensureDir: string => promise<unit> = "ensureDir"
}

// @std/path
module Path = {
  @module("@std/path") external join: (string, string) => string = "join"
  @module("@std/path") external join3: (string, string, string) => string = "join"
  @module("@std/path") external dirname: string => string = "dirname"
}
