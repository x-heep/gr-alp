#!/usr/bin/env python3
# Copyright 2026 Politecnico di Torino
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Author: Luigi Giuffrida
# Description: Renames GR-ALP to a new project name (file contents and paths)

"""
Usage: util/rename.py <name> (or make rename NAME=<name>)

Replaces gr-alp with <name> in each spelling (gr_alp, gr-alp, GR_ALP, GR-ALP), in the
contents and the paths of the project files: SystemVerilog modules, FuseSoC core,
config, apps, CI. hw/vendor (vendored as is), build outputs and this script are left
untouched; symlinks keep their target. Self-test: python3 -m doctest util/rename.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SELF = os.path.relpath(os.path.abspath(__file__), ROOT)
SKIP_DIRS = {".git", ".venv", "build", os.path.join("hw", "vendor")}
OLD = re.compile(r"(g)r([-_])alp", re.IGNORECASE)
# Lowercase SystemVerilog identifier once - becomes _, and a folder and FuseSoC core name
VALID_NAME = re.compile(r"[a-z][a-z0-9]*([-_][a-z0-9]+)*")


def rename(text, name):
    """
    name in place of gr-alp in text, with the separator and the case of each spelling.

    >>> rename("gr_alp u_gr_alp gr-alp.core GR_ALP GR-ALP", "my-soc")
    'my_soc u_my_soc my-soc.core MY_SOC MY-SOC'
    >>> rename("gr_alp_hello_world x-alp", "foo")
    'foo_hello_world x-alp'
    """
    words = re.split(r"[-_]", name)

    def spell(m):
        new = m[2].join(words)
        return new.upper() if m[1] == "G" else new

    return OLD.sub(spell, text)


def project_files():
    """Paths (relative to ROOT) of the project files, not following symlinked folders."""
    files = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        rel = os.path.relpath(dirpath, ROOT)
        dirnames[:] = [
            d
            for d in dirnames
            if os.path.normpath(os.path.join(rel, d)) not in SKIP_DIRS
        ]
        files += [os.path.normpath(os.path.join(rel, f)) for f in filenames]
    return [f for f in files if f != SELF]


def main():
    name = sys.argv[1] if len(sys.argv) == 2 else ""
    if not VALID_NAME.fullmatch(name) or name in ("x-alp", "x_alp"):
        sys.exit(
            "Usage: make rename NAME=<name>: lowercase letters and digits, starting "
            "with a letter, words separated by - or _ (not x-alp)"
        )

    files = project_files()
    moves = {f: rename(f, name) for f in files if rename(f, name) != f}
    clash = [t for t in moves.values() if os.path.lexists(os.path.join(ROOT, t))]
    if clash:
        sys.exit(f"Not renaming: these files already exist: {', '.join(clash)}")

    changed = 0
    for f in files:
        path = os.path.join(ROOT, f)
        if os.path.islink(path):
            continue
        with open(path, "rb") as fh:
            data = fh.read()
        if b"\0" in data:  # binary
            continue
        # latin1: byte for byte, so files that are not UTF-8 come back unchanged
        text = data.decode("latin1")
        new = rename(text, name)
        if new != text:
            with open(path, "wb") as fh:
                fh.write(new.encode("latin1"))
            changed += 1

    emptied = set()
    for f, to in moves.items():
        os.makedirs(os.path.join(ROOT, os.path.dirname(to)), exist_ok=True)
        os.rename(os.path.join(ROOT, f), os.path.join(ROOT, to))
        emptied.add(os.path.dirname(os.path.join(ROOT, f)))
    # The emptied folders (e.g. hw/gr-alp), deepest first
    for d in sorted(emptied, key=len, reverse=True):
        if d != ROOT and not os.listdir(d):
            os.rmdir(d)

    print(f"Renamed to {name}: {changed} files edited, {len(moves)} moved.")
    print("Regenerate with 'make mcu-gen' and rebuild (the old build/ is stale).")


if __name__ == "__main__":
    main()
