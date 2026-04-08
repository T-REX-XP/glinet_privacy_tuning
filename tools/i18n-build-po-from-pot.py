#!/usr/bin/env python3
"""Generate en/uk/de .po files from templates/glinet_privacy.pot."""
from __future__ import annotations

import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "package", "luci-app-glinet-privacy")
POT = os.path.join(ROOT, "po", "templates", "glinet_privacy.pot")

PAT_MSGID = re.compile(r'^msgid "(.*)"\s*$')


def escape_po(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def parse_msgids(path: str) -> tuple[list[str], str]:
    """Return (list of msgids skipping empty catalog), raw header text for first block."""
    with open(path, encoding="utf-8") as fh:
        lines = fh.readlines()
    body_start = 0
    for i, line in enumerate(lines):
        if line.startswith('msgid "') and not line.startswith('msgid ""'):
            body_start = i
            break
    header = "".join(lines[:body_start])
    msgids: list[str] = []
    for line in lines[body_start:]:
        m = PAT_MSGID.match(line.rstrip("\n"))
        if m:
            mid = m.group(1).replace('\\"', '"').replace("\\\\", "\\")
            if mid:
                msgids.append(mid)
    return msgids, header


def patch_header(hdr: str, lang: str, lang_team: str) -> str:
    """Set gettext header Language / Language-Team lines (quoted string continuations)."""
    out: list[str] = []
    for line in hdr.splitlines(True):
        if line.startswith('"Language-Team:'):
            out.append(f'"Language-Team: {lang_team}\\n"\n')
        elif line.startswith('"Language:'):
            out.append(f'"Language: {lang}\\n"\n')
        elif "PO-Revision-Date: YEAR-MO-DA" in line:
            out.append('"PO-Revision-Date: 2026-04-08 12:00+0000\\n"\n')
        else:
            out.append(line)
    return "".join(out)


def write_po(path: str, lang: str, lang_team: str, header: str, msgids: list[str], identity: bool) -> None:
    hdr = patch_header(header, lang, lang_team)
    parts = [hdr.rstrip() + "\n\n"]
    for mid in msgids:
        parts.append(f'msgid "{escape_po(mid)}"\n')
        if identity:
            parts.append(f'msgstr "{escape_po(mid)}"\n')
        else:
            parts.append('msgstr ""\n')
        parts.append("\n")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("".join(parts))


def main() -> None:
    if not os.path.isfile(POT):
        print("Missing POT; run extract-luci-i18n-strings.py first", file=sys.stderr)
        sys.exit(1)
    msgids, header = parse_msgids(POT)
    write_po(os.path.join(ROOT, "po", "en", "glinet_privacy.po"), "en", "English", header, msgids, True)
    write_po(os.path.join(ROOT, "po", "uk", "glinet_privacy.po"), "uk", "Ukrainian", header, msgids, False)
    write_po(os.path.join(ROOT, "po", "de", "glinet_privacy.po"), "de", "German", header, msgids, False)
    print(f"Wrote en (identity), uk/de (empty msgstr → English fallback): {len(msgids)} strings", file=sys.stderr)


if __name__ == "__main__":
    main()
