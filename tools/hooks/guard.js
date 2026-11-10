#!/usr/bin/env node
// PreToolUse hook (registered in .claude/settings.json).
//   exit 2           -> always blocked, stderr is shown to Claude
//   "ask" on stdout  -> Claude Code stops and asks the USER to approve this one call
// So anything that must wait for the user's order is an "ask": Claude cannot
// approve it itself. Editing this file or settings is also an "ask".
const fs = require("fs");

let call;
try { call = JSON.parse(fs.readFileSync(0, "utf8")); } catch { process.exit(0); }
const tool = call.tool_name || "";
const input = call.tool_input || {};
const isShell = tool === "Bash" || tool === "PowerShell";
const cmd = isShell ? String(input.command || "") : "";

function block(msg) { process.stderr.write("BLOCKED by tools/hooks/guard.js: " + msg + "\n"); process.exit(2); }
function ask(msg) {
  process.stdout.write(JSON.stringify({ hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: "tools/hooks/guard.js: " + msg + " Waiting for the user's order.",
  } }));
  process.exit(0);
}

// --- Always blocked (no one-off approval) ---------------------------------
if (isShell) {
  if (/git\s+push\b/.test(cmd) && /--force\b|\s-f(\s|$)|--force-with-lease/.test(cmd)) block("force push is not allowed.");
  if (/--no-verify|--no-gpg-sign/.test(cmd)) block("do not skip git hooks or signing.");
}
if (tool === "Read" && !input.limit && !input.pages && input.file_path) {
  try {
    const size = fs.statSync(input.file_path).size;
    if (size > 40000 && !/\.(png|jpg|jpeg|pdf|svg)$/i.test(input.file_path)) {
      block(`${input.file_path} is ${Math.round(size / 1000)} KB. Use grep -n, then Read with offset and limit (<=150 lines).`);
    }
  } catch { /* missing file: let Read report it */ }
}

// --- Only when the user orders it ------------------------------------------
// 1. git push to main (or any push while on main).
if (isShell && /git\s+push\b/.test(cmd)) {
  let onMain = false;
  try {
    const b = require("child_process").execSync("git rev-parse --abbrev-ref HEAD", { encoding: "utf8" }).trim();
    onMain = b === "main" || b === "master";
  } catch {}
  if (/(\s|:|\/)(main|master)(\s|$)/.test(cmd) || onMain) ask("git push to main.");
}

// 2. The old HTML draft (name built from parts so this file doesn't name it).
const DRAFT = new RegExp("To_Beyond_Dra" + "ft", "i");
const draftText = ["file_path", "path", "pattern", "glob"].map(k => String(input[k] || "")).join(" ") + " " + cmd;
const harmlessGit = /^\s*git\s+(status|log|add|commit|diff|rm|restore)\b[^;&|]*$/;
if (["Read", "Grep", "Glob", "Bash", "PowerShell"].includes(tool) && DRAFT.test(draftText) && !(isShell && harmlessGit.test(cmd))) {
  ask("reading or searching the HTML draft.");
}

// 3. Changing the rules themselves.
const PROTECTED = /(\.claude[\\/]settings(\.local)?\.json|tools[\\/]hooks[\\/])/i;
if ((tool === "Edit" || tool === "Write" || tool === "NotebookEdit") && PROTECTED.test(String(input.file_path || ""))) {
  ask("editing the guard or Claude settings.");
}
if (isShell && PROTECTED.test(cmd) && !/^\s*(git\s+(status|log|diff|show|add|commit)|node\s+tools[\\/]hooks[\\/]test\.js)\b[^;&|]*$/.test(cmd)) {
  ask("a shell command touching the guard or Claude settings.");
}
process.exit(0);
