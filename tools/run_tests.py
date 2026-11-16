#!/usr/bin/env python3
"""Single test entry: runs `flutter test` with a time budget and a time-as-state scan.

Usage: python3 tools/run_tests.py [paths...]   (paths default to `test`)
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PATHS = ["test"]
TEST_BUDGET_S = 1.0
SUITE_BUDGET_S = 40.0
SLOWEST_SHOWN = 10

SLEEP_CALL = re.compile(r"\bsleep\(")
DELAY_CALL = re.compile(r"\b(?:Future(?:<[^>]*>)?\.delayed|Timer(?:\.periodic)?)\(\s*([^,)\n]*)")
ZERO_DURATION = "Duration.zero"


def scan_time_as_state(paths: list[str]) -> list[str]:
    hits: list[str] = []
    for root in paths:
        base = (REPO_ROOT / root).resolve()
        files = [base] if base.is_file() else sorted(base.rglob("*.dart"))
        for f in files:
            for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
                delay = DELAY_CALL.search(line)
                if SLEEP_CALL.search(line) or (delay and delay.group(1).strip() != ZERO_DURATION):
                    hits.append(f"{f.relative_to(REPO_ROOT)}:{n}: {line.strip()}")
    return hits


def run_flutter(paths: list[str]) -> tuple[int, dict, dict, dict, bool, float]:
    suites: dict[int, str] = {}
    starts: dict[int, tuple[str, int, int]] = {}  # id -> (name, suiteID, start ms)
    durations: dict[int, int] = {}
    results: dict[int, tuple[str, bool]] = {}
    errors: dict[int, str] = {}
    success = False
    t0 = time.monotonic()
    proc = subprocess.Popen(
        ["flutter", "test", "--reporter", "json", *paths],
        cwd=REPO_ROOT, stdout=subprocess.PIPE, text=True,
    )
    assert proc.stdout is not None
    for line in proc.stdout:
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            ev = None
        if not isinstance(ev, dict):
            sys.stderr.write(line)
            continue
        kind = ev.get("type")
        if kind == "suite":
            suites[ev["suite"]["id"]] = ev["suite"]["path"]
        elif kind == "testStart":
            t = ev["test"]
            starts[t["id"]] = (t["name"], t["suiteID"], ev["time"])
        elif kind == "testDone":
            tid = ev["testID"]
            if ev.get("hidden"):
                continue
            durations[tid] = ev["time"] - starts[tid][2]
            results[tid] = (ev["result"], bool(ev.get("skipped")))
        elif kind == "error":
            errors[ev["testID"]] = ev["error"]
        elif kind == "done":
            success = bool(ev.get("success"))
    rc = proc.wait()
    wall = time.monotonic() - t0
    rows = {tid: (starts[tid][0], suites.get(starts[tid][1], "?"), durations[tid]) for tid in durations}
    return rc, rows, results, errors, success, wall


def main() -> int:
    paths = sys.argv[1:] or DEFAULT_PATHS
    failures: list[str] = []

    hits = scan_time_as_state(paths)
    for h in hits:
        print(f"time-as-state: {h}")
    if hits:
        failures.append(f"time-as-state scan: expected 0 hits, got {len(hits)}")

    rc, rows, results, errors, success, wall = run_flutter(paths)
    passed = sum(1 for r, s in results.values() if r == "success" and not s)
    skipped = sum(1 for _, s in results.values() if s)
    failed = [tid for tid, (r, _) in results.items() if r != "success"]

    print(f"tests: {len(results)} passed: {passed} failed: {len(failed)} skipped: {skipped} wall: {wall:.1f}s")
    print(f"slowest {SLOWEST_SHOWN}:")
    for name, suite, ms in sorted(rows.values(), key=lambda r: -r[2])[:SLOWEST_SHOWN]:
        print(f"  {ms:6d} ms  {suite}  {name}")
    for tid in failed:
        print(f"FAILED {rows[tid][1]} {rows[tid][0]}\n{errors.get(tid, '')}")

    if rc != 0:
        failures.append(f"flutter exit code: expected 0, got {rc}")
    if not success:
        failures.append("done.success: expected true, got false or missing")
    slow = [(n, s, ms) for n, s, ms in rows.values() if ms > TEST_BUDGET_S * 1000]
    for n, s, ms in slow:
        failures.append(f"test over budget: expected <= {TEST_BUDGET_S * 1000:.0f} ms, got {ms} ms: {s} {n}")
    if wall > SUITE_BUDGET_S:
        failures.append(f"suite over budget: expected <= {SUITE_BUDGET_S}s, got {wall:.1f}s")

    for f in failures:
        print(f"FAIL: {f}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
