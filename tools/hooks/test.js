#!/usr/bin/env node
// node tools/hooks/test.js : checks every rule of guard.js, prints PASS/FAIL per case.
const { spawnSync } = require("child_process");
const path = require("path");
const guard = path.join(__dirname, "guard.js");
const D = "To_Beyond_Dra" + "ft.html";
const big = path.join(__dirname, "..", "..", "scripts", "main.gd");

const cases = [
  // [name, call, expected: "allow" | "ask" | "block"]
  ["read draft", { tool_name: "Read", tool_input: { file_path: "C:/x/" + D } }, "ask"],
  ["grep draft in shell", { tool_name: "Bash", tool_input: { command: "grep -n foo " + D } }, "ask"],
  ["grep tool on draft path", { tool_name: "Grep", tool_input: { pattern: "x", path: "C:/x/" + D } }, "ask"],
  ["git add of draft", { tool_name: "Bash", tool_input: { command: "git add " + D } }, "allow"],
  ["git add then cat draft", { tool_name: "Bash", tool_input: { command: "git add . && cat " + D } }, "ask"],
  ["parity run", { tool_name: "Bash", tool_input: { command: "node tools/parity/parity.js arts --fast" } }, "allow"],
  ["edit doc mentioning draft", { tool_name: "Edit", tool_input: { file_path: "C:/x/CLAUDE.md", new_string: D } }, "allow"],
  ["push main", { tool_name: "Bash", tool_input: { command: "git push origin main" } }, "ask"],
  ["push HEAD:main", { tool_name: "Bash", tool_input: { command: "git push origin HEAD:main" } }, "ask"],
  ["push branch", { tool_name: "Bash", tool_input: { command: "git push -u origin some-branch" } }, "allow*"],
  ["force push", { tool_name: "Bash", tool_input: { command: "git push --force origin some-branch" } }, "block"],
  ["skip hooks", { tool_name: "Bash", tool_input: { command: "git commit --no-" + "verify -m x" } }, "block"],
  ["edit guard", { tool_name: "Edit", tool_input: { file_path: "C:/x/tools/hooks/guard.js" } }, "ask"],
  ["write settings", { tool_name: "Write", tool_input: { file_path: "C:\\x\\.claude\\settings.json" } }, "ask"],
  ["shell sed on settings", { tool_name: "Bash", tool_input: { command: "sed -i s/a/b/ .claude/settings.json" } }, "ask"],
  ["shell rm guard", { tool_name: "PowerShell", tool_input: { command: "Remove-Item tools\\hooks\\guard.js" } }, "ask"],
  ["git diff of guard", { tool_name: "Bash", tool_input: { command: "git diff tools/hooks/guard.js" } }, "allow"],
  ["big read no limit", { tool_name: "Read", tool_input: { file_path: big } }, "block"],
  ["big read with limit", { tool_name: "Read", tool_input: { file_path: big, limit: 100 } }, "allow"],
  ["edit normal script", { tool_name: "Edit", tool_input: { file_path: "C:/x/scripts/main.gd" } }, "allow"],
];

let bad = 0;
for (const [name, c, want] of cases) {
  const r = spawnSync("node", [guard], { input: JSON.stringify(c), encoding: "utf8" });
  const got = r.status === 2 ? "block" : /"ask"/.test(r.stdout) ? "ask" : "allow";
  const ok = want === got || (want === "allow*" && (got === "allow" || got === "ask")); // *: "ask" if the current git branch is main
  if (!ok) bad++;
  console.log((ok ? "PASS " : "FAIL ") + name.padEnd(28) + "want " + want + ", got " + got);
}
console.log(bad ? `${bad} FAILED` : "all passed");
process.exit(bad ? 1 : 0);
