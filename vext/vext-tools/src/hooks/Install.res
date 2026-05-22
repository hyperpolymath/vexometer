// SPDX-License-Identifier: MPL-2.0
// vext hook installer
// Installs git hooks for vext notifications.

open Deno
open Std

let hookTemplate = `#!/bin/sh
# vext post-receive hook
# Sends commit notifications to IRC via vextd
#
# Configuration (set in environment or uncomment below):
# export VEXT_SERVER="127.0.0.1:6659"
# export VEXT_TARGETS="irc://irc.libera.chat/your-channel"
# export VEXT_PROJECT="your-project"
# export VEXT_URL="https://github.com/you/repo"

# Run the hook
exec deno run --allow-net --allow-env --allow-read \\
  "HOOK_PATH" "$@"
`

// Find git directory
let findGitDir = async (): option<string> => {
  let cmd = Command.make("git", {
    args: ["rev-parse", "--git-dir"],
    stdout: "piped",
    stderr: "null",
  })
  let output = await cmd->Command.output
  if !output.success {
    None
  } else {
    let decoder = TextDecoder.make()
    Some(decoder->TextDecoder.decode(output.stdout)->String.trim)
  }
}

// Install the hook
let installHook = async (gitDir: string, hookPath: string, force: bool): bool => {
  let hooksDir = Path.join(gitDir, "hooks")
  let targetPath = Path.join(hooksDir, "post-receive")

  // Check if hook already exists
  try {
    let _ = await stat(targetPath)
    if !force {
      Console.error(`Hook already exists: ${targetPath}`)
      Console.error("Use --force to overwrite")
      return false
    }
  } catch {
  | _ => () // File doesn't exist, that's fine
  }

  await Fs.ensureDir(hooksDir)

  // Generate hook content
  let content = hookTemplate->String.replaceAll("HOOK_PATH", hookPath)

  await writeTextFile(targetPath, content)
  await chmod(targetPath, 0o755)

  Console.log(`Installed hook: ${targetPath}`)
  true
}

// Show help
let showHelp = () => {
  Console.log(`vext hook installer

Usage: Install.res.mjs [options]

Options:
  --git-dir     Path to .git directory (auto-detected if not specified)
  --hook-path   Path to the Git.res.mjs hook script
  --force, -f   Overwrite existing hook
  --help, -h    Show this help

Example:
  deno run --allow-read --allow-write Install.res.mjs --force
`)
}

// Main entry point
let main = async () => {
  let args = Deno.args

  // Check for help flag
  let showHelpFlag = args->Array.some(a => a == "--help" || a == "-h")
  if showHelpFlag {
    showHelp()
    exit(0)
  }

  // Parse arguments
  let gitDirArg = ref(None)
  let hookPathArg = ref(None)
  let forceFlag = ref(false)

  args->Array.forEachWithIndex((arg, i) => {
    if arg == "--git-dir" {
      gitDirArg := args->Array.get(i + 1)
    }
    if arg == "--hook-path" {
      hookPathArg := args->Array.get(i + 1)
    }
    if arg == "--force" || arg == "-f" {
      forceFlag := true
    }
  })

  // Find git directory
  let gitDir = switch gitDirArg.contents {
  | Some(d) => d
  | None =>
    switch await findGitDir() {
    | Some(d) => d
    | None =>
      Console.error("Not in a git repository. Use --git-dir to specify.")
      exit(1)
      "" // unreachable
    }
  }

  // Find hook script path
  let hookPath = switch hookPathArg.contents {
  | Some(p) => p
  | None =>
    // Default to Git.res.mjs in the same directory
    // This assumes the compiled ReScript output
    Path.join(Path.dirname("./"), "Git.res.mjs")
  }

  // Install the hook
  let success = await installHook(gitDir, hookPath, forceFlag.contents)

  if success {
    let postReceivePath = Path.join3(gitDir, "hooks", "post-receive")
    Console.log(`
Hook installed successfully!

Configure by setting environment variables:
  VEXT_SERVER      vextd server (default: 127.0.0.1:6659)
  VEXT_TARGETS     IRC targets, comma-separated
  VEXT_PROJECT     Project name
  VEXT_URL         Base URL for commit links

Or edit the hook file directly:
  ${postReceivePath}
`)
  } else {
    exit(1)
  }
}

// Run main
let _ = main()->Promise.catch(err => {
  let msg = switch err {
  | Js.Exn.Error(e) => Js.Exn.message(e)->Option.getOr("unknown")
  | _ => "unknown error"
  }
  Console.error(`Error: ${msg}`)
  exit(1)
  Promise.resolve()
})
