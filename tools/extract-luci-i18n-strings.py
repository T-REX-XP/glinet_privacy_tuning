#!/usr/bin/env python3
"""Extract translate() / translatef() / tr() / <%: %> strings for luci-app-glinet-privacy."""
from __future__ import annotations

import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "package", "luci-app-glinet-privacy")

PAT_TRANSLATE = re.compile(r'translate\s*\(\s*"([^"]*)"')
PAT_TRANSLATE2 = re.compile(r"translate\s*\(\s*'([^']*)'")
PAT_TRANSLATEF = re.compile(r'translatef\s*\(\s*"([^"]*)"')
PAT_TRANSLATEF2 = re.compile(r"translatef\s*\(\s*'([^']*)'")
PAT_UNDERSCORE = re.compile(r'_\(\s*"([^"]*)"')
PAT_UNDERSCORE2 = re.compile(r"_\(\s*'([^']*)'")
PAT_TR = re.compile(r'\btr\s*\(\s*"([^"]*)"')
PAT_TR2 = re.compile(r"\btr\s*\(\s*'([^']*)'")
PAT_HTM = re.compile(r"<%:([^%]+)%>")


def collect() -> list[str]:
    msgs: list[str] = []
    for dp, _, fs in os.walk(ROOT):
        for f in fs:
            if not (f.endswith(".lua") or f.endswith(".htm")):
                continue
            path = os.path.join(dp, f)
            with open(path, encoding="utf-8", errors="replace") as fh:
                s = fh.read()
            for pat in (
                PAT_TRANSLATE,
                PAT_TRANSLATE2,
                PAT_TRANSLATEF,
                PAT_TRANSLATEF2,
                PAT_UNDERSCORE,
                PAT_UNDERSCORE2,
                PAT_TR,
                PAT_TR2,
            ):
                msgs.extend(m.group(1) for m in pat.finditer(s))
            for m in PAT_HTM.finditer(s):
                t = m.group(1).strip()
                if t:
                    msgs.append(t)
    seen: set[str] = set()
    out: list[str] = []
    for m in msgs:
        if m not in seen:
            seen.add(m)
            out.append(m)
    return out


def escape_po(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def write_pot(path: str, msgs: list[str]) -> None:
    lines = [
        'msgid ""',
        'msgstr ""',
        '"Project-Id-Version: luci-app-glinet-privacy\\n"',
        '"Report-Msgid-Bugs-To: \\n"',
        '"POT-Creation-Date: 2026-04-08 12:00+0000\\n"',
        '"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\\n"',
        '"Last-Translator: \\n"',
        '"Language-Team: \\n"',
        '"Language: \\n"',
        '"MIME-Version: 1.0\\n"',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        '"Content-Transfer-Encoding: 8bit\\n"',
        "",
    ]
    for m in msgs:
        lines.append(f'msgid "{escape_po(m)}"')
        lines.append('msgstr ""')
        lines.append("")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))


if __name__ == "__main__":
    msgs = collect()
    out = os.path.join(ROOT, "po", "templates", "glinet_privacy.pot")
    write_pot(out, msgs)
    print(f"Wrote {len(msgs)} messages to {out}", file=sys.stderr)
