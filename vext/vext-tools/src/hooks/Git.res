// SPDX-License-Identifier: MPL-2.0
// vext Git post-receive hook
// Reads pushed refs from stdin and sends notifications to vextd.

open Deno

// Types
type commitInfo = {
  hash: string,
  shortHash: string,
  author: string,
  authorEmail: string,
  subject: string,
  body: string,
  timestamp: string,
}

type refUpdate = {
  oldRef: string,
  newRef: string,
  refName: string,
}

type notification = {
  to: array<string>,
  privmsg: string,
  project: option<string>,
  branch: option<string>,
  commit: option<string>,
  author: option<string>,
  url: option<string>,
}

// Configuration from environment
type config = {
  mutable server: string,
  mutable targets: array<string>,
  mutable project: option<string>,
  mutable baseUrl: option<string>,
  mutable maxCommits: int,
  mutable colors: bool,
}

let defaultConfig = (): config => {
  let server = Env.get("VEXT_SERVER")->Option.getOr("127.0.0.1:6659")
  let targetsStr = Env.get("VEXT_TARGETS")->Option.getOr("")
  let targets = targetsStr->String.split(",")->Array.filter(s => s != "")
  let project = switch Env.get("VEXT_PROJECT") {
  | Some(p) => Some(p)
  | None => Env.get("GL_PROJECT_PATH")
  }
  let baseUrl = Env.get("VEXT_URL")
  let maxCommits = Env.get("VEXT_MAX_COMMITS")
    ->Option.flatMap(s => Int.fromString(s))
    ->Option.getOr(5)
  let colors = Env.get("VEXT_COLORS") != Some("false")

  {server, targets, project, baseUrl, maxCommits, colors}
}

// Run git command and get output
let runGit = async (args: array<string>): string => {
  let cmd = Command.make("git", {
    args,
    stdout: "piped",
    stderr: "piped",
  })
  let output = await cmd->Command.output
  if !output.success {
    Js.Exn.raiseError(`git ${args->Array.join(" ")} failed`)
  }
  let decoder = TextDecoder.make()
  decoder->TextDecoder.decode(output.stdout)->String.trim
}

// Get commit info for a hash
let getCommitInfo = async (hash: string): commitInfo => {
  let format = "%H%n%h%n%an%n%ae%n%s%n%b%n%aI"
  let output = await runGit(["log", "-1", `--format=${format}`, hash])
  let lines = output->String.split("\n")

  {
    hash: lines->Array.getUnsafe(0),
    shortHash: lines->Array.getUnsafe(1),
    author: lines->Array.getUnsafe(2),
    authorEmail: lines->Array.getUnsafe(3),
    subject: lines->Array.getUnsafe(4),
    body: lines->Array.slice(~start=5, ~end=-1)->Array.join("\n"),
    timestamp: lines->Array.getUnsafe(Array.length(lines) - 1),
  }
}

// Get commits between two refs
let getCommitsBetween = async (config: config, oldRef: string, newRef: string): array<string> => {
  let nullRef = "0000000000000000000000000000000000000000"

  // Handle new branch
  if oldRef == nullRef {
    let output = await runGit([
      "rev-list",
      `--max-count=${config.maxCommits->Int.toString}`,
      newRef,
    ])
    output->String.split("\n")->Array.filter(s => s != "")
  } else if newRef == nullRef {
    // Handle deleted branch
    []
  } else {
    let output = await runGit([
      "rev-list",
      `--max-count=${config.maxCommits->Int.toString}`,
      `${oldRef}..${newRef}`,
    ])
    output->String.split("\n")->Array.filter(s => s != "")
  }
}

// Extract branch name from ref
let extractBranchName = (refName: string): string => {
  if refName->String.startsWith("refs/heads/") {
    refName->String.sliceToEnd(~start=11)
  } else if refName->String.startsWith("refs/tags/") {
    "tag/" ++ refName->String.sliceToEnd(~start=10)
  } else {
    refName
  }
}

// Format commit message
let formatCommitMessage = (commit: commitInfo, branch: string, project: option<string>): string => {
  let parts = []

  switch project {
  | Some(p) => parts->Array.push(`[${p}]`)->ignore
  | None => ()
  }

  parts->Array.push(branch)->ignore
  parts->Array.push(commit.shortHash)->ignore
  parts->Array.push(commit.author ++ ":")->ignore
  parts->Array.push(commit.subject)->ignore

  parts->Array.join(" ")
}

// Send notification to vextd
let sendNotification = async (config: config, notification: notification): unit => {
  let payload = notification->Obj.magic->JSON.stringify ++ "\n"

  try {
    let serverParts = config.server->String.split(":")
    let hostname = serverParts->Array.getUnsafe(0)
    let port = serverParts->Array.get(1)
      ->Option.flatMap(Int.fromString)
      ->Option.getOr(6659)

    let conn = await Net.connect({hostname, port})
    let encoder = TextEncoder.make()
    let _ = await conn->Net.write(encoder->TextEncoder.encode(payload))
    conn->Net.close

    Console.error(`[vext] Sent notification to ${config.server}`)
  } catch {
  | Js.Exn.Error(err) =>
    let msg = Js.Exn.message(err)->Option.getOr("unknown error")
    Console.error(`[vext] Failed to send notification: ${msg}`)
  }
}

// Process a ref update
let processRefUpdate = async (config: config, update: refUpdate): unit => {
  if Array.length(config.targets) == 0 {
    Console.error("[vext] No targets configured (set VEXT_TARGETS)")
    return
  }

  let branch = extractBranchName(update.refName)
  let nullRef = "0000000000000000000000000000000000000000"

  // Handle branch deletion
  if update.newRef == nullRef {
    await sendNotification(config, {
      to: config.targets,
      privmsg: `Branch ${branch} deleted`,
      project: config.project,
      branch: Some(branch),
      commit: None,
      author: None,
      url: None,
    })
    return
  }

  // Handle new branch
  if update.oldRef == nullRef {
    await sendNotification(config, {
      to: config.targets,
      privmsg: `New branch ${branch} created`,
      project: config.project,
      branch: Some(branch),
      commit: None,
      author: None,
      url: None,
    })
  }

  // Get commits
  let commits = await getCommitsBetween(config, update.oldRef, update.newRef)

  if Array.length(commits) == 0 {
    return
  }

  // Process each commit (most recent first)
  let reversed = commits->Array.toReversed
  for i in 0 to Array.length(reversed) - 1 {
    let hash = reversed->Array.getUnsafe(i)
    try {
      let commit = await getCommitInfo(hash)
      let message = formatCommitMessage(commit, branch, config.project)

      let url = switch config.baseUrl {
      | Some(base) => Some(`${base}/commit/${commit.hash}`)
      | None => None
      }

      await sendNotification(config, {
        to: config.targets,
        privmsg: message,
        project: config.project,
        branch: Some(branch),
        commit: Some(commit.shortHash),
        author: Some(commit.author),
        url,
      })
    } catch {
    | Js.Exn.Error(err) =>
      let msg = Js.Exn.message(err)->Option.getOr("unknown")
      Console.error(`[vext] Failed to process commit ${hash}: ${msg}`)
    }
  }

  // If there were more commits, note that
  if Array.length(commits) >= config.maxCommits {
    await sendNotification(config, {
      to: config.targets,
      privmsg: `... and more commits (showing last ${config.maxCommits->Int.toString})`,
      project: config.project,
      branch: Some(branch),
      commit: None,
      author: None,
      url: None,
    })
  }
}

// Read ref updates from stdin
let readStdin = async (): array<refUpdate> => {
  let updates: array<refUpdate> = []
  let decoder = TextDecoder.make()
  let buffer = Js.TypedArray2.Uint8Array.fromLength(1024)
  let input = ref("")

  try {
    let continue = ref(true)
    while continue.contents {
      let n = await Stdin.stdin->Stdin.read(buffer)
      switch n->Js.Nullable.toOption {
      | None => continue := false
      | Some(bytesRead) =>
        let slice = buffer->Js.TypedArray2.Uint8Array.slice(~start=0, ~end_=bytesRead)
        input := input.contents ++ decoder->TextDecoder.decode(slice)
      }
    }
  } catch {
  | _ => () // stdin might not be available
  }

  // Parse ref updates
  let lines = input.contents->String.split("\n")
  lines->Array.forEach(line => {
    let trimmed = line->String.trim
    if trimmed != "" {
      let parts = trimmed->String.split(" ")
      if Array.length(parts) >= 3 {
        updates->Array.push({
          oldRef: parts->Array.getUnsafe(0),
          newRef: parts->Array.getUnsafe(1),
          refName: parts->Array.getUnsafe(2),
        })->ignore
      }
    }
  })

  updates
}

// Show help
let showHelp = () => {
  Console.log(`vext git hook - Send commit notifications to IRC

Usage: Git.res.mjs [options]

When run as a git post-receive hook, reads ref updates from stdin.

Options:
  --server    vextd server address (default: 127.0.0.1:6659)
  --to        IRC target URL (can specify multiple)
  --project   Project name
  --url       Base URL for commit links
  --help      Show this help
  --version   Show version

Environment variables:
  VEXT_SERVER      vextd server address
  VEXT_TARGETS     Comma-separated IRC target URLs
  VEXT_PROJECT     Project name
  VEXT_URL         Base URL for commit links
  VEXT_MAX_COMMITS Maximum commits to report (default: 5)
`)
}

// Main entry point
let main = async () => {
  let config = defaultConfig()

  // Simple arg parsing
  let args = Deno.args
  let showHelpFlag = args->Array.some(a => a == "--help" || a == "-h")
  let showVersion = args->Array.some(a => a == "--version" || a == "-V")

  if showHelpFlag {
    showHelp()
    exit(0)
  }

  if showVersion {
    Console.log("vext-hook 1.0.0")
    exit(0)
  }

  // Parse CLI args for overrides
  args->Array.forEachWithIndex((arg, i) => {
    if arg == "--server" {
      switch args->Array.get(i + 1) {
      | Some(v) => config.server = v
      | None => ()
      }
    }
    if arg == "--to" {
      switch args->Array.get(i + 1) {
      | Some(v) => config.targets = [v]
      | None => ()
      }
    }
    if arg == "--project" {
      switch args->Array.get(i + 1) {
      | Some(v) => config.project = Some(v)
      | None => ()
      }
    }
    if arg == "--url" {
      switch args->Array.get(i + 1) {
      | Some(v) => config.baseUrl = Some(v)
      | None => ()
      }
    }
  })

  // Read ref updates from stdin
  let updates = await readStdin()

  if Array.length(updates) == 0 {
    Console.error("[vext] No ref updates received from stdin")
    exit(0)
  }

  // Process each ref update
  for i in 0 to Array.length(updates) - 1 {
    let update = updates->Array.getUnsafe(i)
    await processRefUpdate(config, update)
  }
}

// Run main
let _ = main()->Promise.catch(err => {
  let msg = switch err {
  | Js.Exn.Error(e) => Js.Exn.message(e)->Option.getOr("unknown")
  | _ => "unknown error"
  }
  Console.error(`[vext] Fatal error: ${msg}`)
  exit(1)
  Promise.resolve()
})
