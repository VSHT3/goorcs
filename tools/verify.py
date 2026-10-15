#!/usr/bin/env python3
"""Run the Godot regression suites without touching the working project or saves."""

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid


ROOT = Path(__file__).resolve().parents[1]
ENGINE_VERSION = "4.7.2.stable.official.ed1daf0bf"
RENDERED_TESTS = {
    "enemy_death_presentation_test.gd",
    "enemy_inspection_test.gd",
    "horde_presentation_test.gd",
    "menu_wordmark_test.gd",
    "orcieary_screen_test.gd",
    "path_board_test.gd",
    "tower_icon_test.gd",
}
# Exact diagnostic bodies and counts only; never exempt an entire negative suite.
# A new negative test must add its deliberate push_error diagnostics here.
EXPECTED_ERRORS = {}
ERROR_LINE = re.compile(r"^\s*(?:SCRIPT ERROR:|ERROR:|USER ERROR:|FATAL:|CRASH:)(.*)$")
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")


class VerificationError(Exception):
    pass


def discover_tests():
    tests = []
    workers = []
    for path in sorted((ROOT / "tests").rglob("*.gd")):
        relative = path.relative_to(ROOT).as_posix()
        if path.name.endswith("_worker.gd"):
            workers.append(relative)
        elif path.name.endswith("_test.gd"):
            tests.append((relative, "rendered" if path.name in RENDERED_TESTS else "headless"))
        else:
            raise VerificationError(f"Unclassified test script {relative}; use *_test.gd or *_worker.gd")
    if not tests:
        raise VerificationError("No tests discovered")
    missing = RENDERED_TESTS - {Path(path).name for path, _ in tests}
    if missing:
        raise VerificationError(f"Rendered classification references missing tests: {sorted(missing)}")
    for path, mode in tests:
        source = (ROOT / path).read_text(encoding="utf-8")
        if mode == "headless" and 'DisplayServer.get_name() == "headless"' in source:
            raise VerificationError(f"{path} checks for a graphical renderer; classify it in RENDERED_TESTS")
    return tests, workers


def copy_project(destination, log_dir, marker):
    excluded = {".git", ".godot", ".verify-logs", ".github", "tools", "docs", "archive_assets",
                "builds", "exports", "__pycache__", "API.txt", ".mcp.json", "export_credentials.cfg"}

    def ignored(directory, names):
        return [name for name in names if name in excluded or name.startswith(".env")
                or (Path(directory) / name).resolve() == log_dir]

    shutil.copytree(ROOT, destination, ignore=ignored)
    config = destination / "project.godot"
    lines = config.read_text(encoding="utf-8").splitlines()
    output = []
    application = False
    found = False
    for line in lines:
        if line.startswith("["):
            application = line == "[application]"
            if application:
                found = True
                output.extend([line, f'config/name="{marker}"', 'config/use_custom_user_dir=true',
                               f'config/custom_user_dir_name="{marker}"',
                               f'config/custom_user_dir_name.windows="{marker}"',
                               f'config/custom_user_dir_name.macos="{marker}"'])
                continue
        if application and re.match(r"config/(?:name|use_custom_user_dir|custom_user_dir_name)(?:\.[^=]+)?=", line):
            continue
        output.append(line)
    if not found:
        raise VerificationError("project.godot has no [application] section")
    config.write_text("\n".join(output) + "\n", encoding="utf-8")
    # A unique copied-project identity makes even the pre-probe initialization safe.
    (destination / "_verify_user_dir.gd").write_text(
        'extends SceneTree\n\nfunc _initialize() -> void:\n'
        '\tprint("VERIFY_USER_DIR=" + OS.get_user_data_dir())\n\tquit()\n', encoding="utf-8")


def process_snapshot():
    # Godot OS.create_process() calls setsid() on Unix. Killing only the original
    # Python-created process group would leave real host/client workers alive.
    result = subprocess.run(["ps", "-axww", "-o", "uid=,pid=,ppid=,pgid=,stat=,command="],
                            capture_output=True, text=True, timeout=10, check=True)
    rows = []
    for line in result.stdout.splitlines():
        parts = line.strip().split(None, 5)
        if len(parts) == 6 and int(parts[0]) == os.geteuid() and parts[4][0] not in ("Z", "X"):
            rows.append((int(parts[1]), int(parts[2]), int(parts[3]), parts[5]))
    return rows


def find_groups(process, marker, known):
    rows = process_snapshot()
    descendants = {process.pid}
    while True:
        more = {pid for pid, parent, _, _ in rows if parent in descendants}
        if more <= descendants:
            break
        descendants.update(more)
    # A vanishing process may report PGID 0. killpg(0, ...) targets our own
    # current group, not that process, so only concrete positive groups qualify.
    groups = {group for pid, _, group, command in rows
              if group > 1 and (pid in descendants or marker in command)}
    groups.add(process.pid)
    groups.discard(os.getpgrp())
    known.update(groups)
    return {group for _, _, group, _ in rows if group > 1 and group != os.getpgrp()}


def stop_groups(process, marker, known):
    # A second interrupt must not cut cleanup short.
    previous = {sig: signal.signal(sig, signal.SIG_IGN) for sig in (signal.SIGINT, signal.SIGTERM)}
    failures = []
    known.add(process.pid)
    try:
        for sig in (signal.SIGTERM, signal.SIGKILL):
            try:
                live_groups = find_groups(process, marker, known)
            except (OSError, subprocess.SubprocessError) as error:
                failures.append(str(error))
                live_groups = {process.pid} if process.poll() is None else set()
            # TERM may have already retired a whole session. Never send KILL
            # to stale accumulated group IDs (Darwin can report EPERM for them).
            for group in sorted(known & live_groups):
                try:
                    os.killpg(group, sig)
                except ProcessLookupError:
                    pass
                except PermissionError as error:
                    try:
                        current_groups = find_groups(process, marker, known)
                    except (OSError, subprocess.SubprocessError) as inspection_error:
                        failures.append(str(inspection_error))
                        current_groups = {group}
                    if group in current_groups:
                        failures.append(f"cannot send {sig.name} to live process group {group}: {error}")
                except OSError as error:
                    failures.append(f"cannot send {sig.name} to process group {group}: {error}")
            if sig == signal.SIGTERM:
                time.sleep(0.2)
        process.wait(timeout=10)
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)
    if failures:
        raise VerificationError("Process-tree cleanup failed: " + "; ".join(failures))


class Runner:
    def __init__(self, engine, project, workspace, logs, marker, environment, timeout, selected):
        self.engine = engine
        self.project = project
        self.workspace = workspace
        self.logs = logs
        self.marker = marker
        self.environment = environment
        self.timeout = timeout
        self.results = []
        self.planned = [path for path, _ in selected]

    def check(self, name, arguments, *, timeout=None, test=None):
        directory = self.logs / name.replace("/", "_").replace(".gd", "")
        directory.mkdir()
        command = [self.engine, *arguments]
        if name != "version":
            command += ["--path", str(self.project), "--log-file", str(directory / "engine.log")]
        (directory / "command.json").write_text(json.dumps(command, indent=2) + "\n", encoding="utf-8")
        started = time.monotonic()
        problems = []
        output = directory / "output.log"
        groups = set()
        print(f"RUN  {name}", flush=True)
        with output.open("w", encoding="utf-8") as stream:
            process = subprocess.Popen(command, cwd=self.project, env=self.environment,
                                       stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                deadline = started + (timeout if timeout is not None else self.timeout)
                while process.poll() is None:
                    find_groups(process, self.marker, groups)
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        problems.append("timed out")
                        break
                    try:
                        process.wait(timeout=min(0.25, remaining))
                    except subprocess.TimeoutExpired:
                        pass
            finally:
                stop_groups(process, self.marker, groups)
        text = ANSI.sub("", output.read_text(encoding="utf-8", errors="replace"))
        if process.returncode:
            problems.append(f"exit {process.returncode}")
        diagnostics = Counter()
        for line in text.splitlines():
            match = ERROR_LINE.match(line)
            if match:
                diagnostics[match.group(1).strip()] += 1
        expected = Counter(EXPECTED_ERRORS.get(test, {}))
        for diagnostic, count in (diagnostics - expected).items():
            problems.append(f"unexpected Godot error ({count}): {diagnostic}")
        for diagnostic, count in (expected - diagnostics).items():
            problems.append(f"missing expected Godot error ({count}): {diagnostic}")
        if test and not re.search(r"^PASS:", text, re.MULTILINE):
            problems.append("missing test PASS marker")
        if name == "version" and text.strip() != ENGINE_VERSION:
            problems.append(f"requires {ENGINE_VERSION}, got {text.strip()!r}")
        if name == "save-isolation":
            reported = re.findall(r"^VERIFY_USER_DIR=(.+)$", text, re.MULTILINE)
            if len(reported) != 1:
                problems.append("missing unique user-directory probe result")
            else:
                actual = Path(reported[0]).resolve()
                if self.workspace not in actual.parents or self.marker not in actual.parts:
                    problems.append(f"unsafe user directory: {actual}")
        elapsed = round(time.monotonic() - started, 2)
        result = {"name": name, "passed": not problems, "seconds": elapsed,
                  "problems": problems, "log": str(output)}
        self.results.append(result)
        print(f"{'FAIL' if problems else 'PASS'} {name} ({elapsed:.2f}s)", flush=True)
        for problem in problems:
            print(f"     {problem}", flush=True)
        self.save_summary()
        return not problems

    def save_summary(self, error=None):
        completed = {item["name"] for item in self.results}
        summary = {"engine": self.engine, "required_version": ENGINE_VERSION,
                   "checks": self.results, "not_run": [path for path in self.planned if path not in completed],
                   "error": error}
        (self.logs / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("headless", "rendered", "all"))
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"),
                        help="engine executable (default: GODOT_BIN or godot on PATH)")
    parser.add_argument("--timeout", type=float, default=180, help="seconds per test (default: 180)")
    parser.add_argument("--import-timeout", type=float, default=300, help="seconds for resource import")
    parser.add_argument("--log-dir", type=Path, help="new durable log directory (must not exist)")
    args = parser.parse_args()
    if not all(math.isfinite(value) and value > 0 for value in (args.timeout, args.import_timeout)):
        parser.error("timeouts must be finite and positive")
    if sys.platform not in ("darwin", "linux"):
        parser.error("verification currently supports macOS and Linux; Unix process-group cleanup is required")
    marker = "gorcs-verify-" + uuid.uuid4().hex
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    logs = (args.log_dir or ROOT / ".verify-logs" / f"{stamp}-{args.mode}-{marker[-8:]}").resolve()
    try:
        logs.mkdir(parents=True, exist_ok=False)
    except OSError as error:
        parser.error(f"cannot create a new log directory {logs}: {error}")
    print(f"Logs: {logs}", flush=True)
    runner = None
    interrupted = False

    def interrupt(signum, frame):
        raise KeyboardInterrupt(f"signal {signum}")

    previous = {sig: signal.signal(sig, interrupt) for sig in (signal.SIGINT, signal.SIGTERM)}
    try:
        engine = shutil.which(args.godot)
        if not engine:
            raise VerificationError(f"Godot executable not found: {args.godot}")
        engine = str(Path(engine).resolve())
        tests, workers = discover_tests()
        selected = [(path, mode) for path, mode in tests if args.mode in (mode, "all")]
        inventory = {"mode": args.mode, "tests": [{"path": path, "mode": mode,
                     "selected": (path, mode) in selected} for path, mode in tests], "workers": workers}
        (logs / "inventory.json").write_text(json.dumps(inventory, indent=2) + "\n", encoding="utf-8")
        for path, mode in tests:
            print(f"{'SELECT' if (path, mode) in selected else 'OTHER MODE'} {mode:8} {path}")
        for worker in workers:
            print(f"WORKER (owned by peer suites, not standalone) {worker}")
        with tempfile.TemporaryDirectory(prefix=marker + "-") as temporary:
            workspace = Path(temporary).resolve()
            project = workspace / "project"
            copy_project(project, logs, marker)
            environment = os.environ.copy()
            for variable, folder in {"HOME": "home", "XDG_DATA_HOME": "data", "XDG_CONFIG_HOME": "config",
                                     "XDG_CACHE_HOME": "cache", "TMPDIR": "tmp", "TMP": "tmp", "TEMP": "tmp"}.items():
                path = workspace / folder
                path.mkdir(exist_ok=True)
                environment[variable] = str(path)
            runner = Runner(engine, project, workspace, logs, marker, environment, args.timeout, selected)
            try:
                if not runner.check("version", ["--version"], timeout=15):
                    return 1
                config_path = project / "project.godot"
                imported_config = config_path.read_text(encoding="utf-8")
                # Godot loads the project GUI font before a clean --import has
                # generated its fontdata. Omit only that early setting while
                # importing the font normally, then restore the exact config.
                bootstrap_config = re.sub(r"(?m)^theme/custom_font(?:\.[^=\r\n]+)?=.*(?:\n|$)",
                                          "", imported_config)
                try:
                    config_path.write_text(bootstrap_config, encoding="utf-8")
                    if not runner.check("import", ["--headless", "--editor", "--import"],
                                        timeout=args.import_timeout):
                        return 1
                finally:
                    config_path.write_text(imported_config, encoding="utf-8")
                if not runner.check("save-isolation", ["--headless", "--script", "res://_verify_user_dir.gd"], timeout=30):
                    return 1
                modes = ("headless", "rendered") if args.mode == "all" else (args.mode,)
                for mode in modes:
                    flags = ["--headless"] if mode == "headless" else ["--rendering-method", "gl_compatibility"]
                    if not runner.check(f"startup-{mode}", [*flags, "--quit-after", "10"], timeout=30):
                        return 1
                    for path, classification in selected:
                        if classification == mode:
                            runner.check(path, [*flags, "--script", "res://" + path], test=path)
            finally:
                # Peer suites normally remove their own logs, but failed/timed-out
                # workers leave useful evidence in this isolated temporary tree.
                for path in (workspace / "tmp").rglob("*.log"):
                    target = logs / "worker-logs" / path.relative_to(workspace / "tmp")
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, target)
        return 1 if any(not item["passed"] for item in runner.results) else 0
    except KeyboardInterrupt:
        interrupted = True
        message = "Verification interrupted; spawned process groups stopped"
        print(message, file=sys.stderr)
        if runner:
            runner.save_summary(message)
        else:
            (logs / "summary.json").write_text(json.dumps({"error": message}) + "\n", encoding="utf-8")
        return 130
    except (VerificationError, OSError, subprocess.SubprocessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        if runner:
            runner.save_summary(str(error))
        else:
            (logs / "summary.json").write_text(json.dumps({"error": str(error)}) + "\n", encoding="utf-8")
        return 1
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)
        if runner:
            passed = sum(item["passed"] for item in runner.results)
            print(f"Summary: {passed}/{len(runner.results)} checks passed" + ("; interrupted" if interrupted else ""))
            completed = {item["name"] for item in runner.results}
            not_run = [path for path in runner.planned if path not in completed]
            if not_run:
                print(f"NOT RUN ({len(not_run)}; stopped at a gate or interruption): {', '.join(not_run)}")
        print(f"Logs retained: {logs}", flush=True)


if __name__ == "__main__":
    sys.exit(main())
