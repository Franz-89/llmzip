"""Phase 0 savings estimator (throwaway code).

Greedy dictionary substitution of repeated word-aligned phrases, measured with
several tokenizers. Token counts always cover the full Direct-mode envelope:
format instruction + legend + payload. Code blocks and inline code are
protected. Two notations are compared: opaque IDs (§0) and mnemonic aliases
(§AuthSvc).

Usage: .venv/bin/python feasibility/estimate.py [--out feasibility/results]
"""

from __future__ import annotations

import argparse
import glob
import json
import re
import statistics
import time
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

INSTRUCTION = (
    "The document after `---` is compressed with a dictionary. Each line "
    "`{s}ID=text` before `---` defines an abbreviation: read every `{s}ID` in "
    "the document as that exact text. Always write the expanded text in your "
    "answers, never the abbreviations.\n"
)

SIGIL_CANDIDATES = ["§", "¤", "¶", "†", "‡", "µ", "※", "¦"]
ID_CHARS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
MAX_UNITS = 31  # longest candidate, in units (word, punct, whitespace)
BATCH = 32  # non-conflicting candidates applied per greedy iteration
THRESHOLD = 0.05


# --- tokenizer profiles ------------------------------------------------------


class Profile:
    def __init__(self, name: str):
        self.name = name
        self._cache: dict[str, int] = {}
        if name in ("o200k", "cl100k"):
            import tiktoken

            enc = tiktoken.get_encoding(f"{name}_base")
            self._batch = lambda xs: [len(t) for t in enc.encode_ordinary_batch(xs)]
        else:
            from tokenizers import Tokenizer

            tok = Tokenizer.from_pretrained(name)
            self._batch = lambda xs: [
                len(e.ids) for e in tok.encode_batch(xs, add_special_tokens=False)
            ]

    def count(self, s: str) -> int:
        return self.count_many([s])[0]

    def count_many(self, xs: list[str]) -> list[int]:
        missing = list({x for x in xs if x not in self._cache})
        if missing:
            for x, n in zip(missing, self._batch(missing)):
                self._cache[x] = n
        return [self._cache[x] for x in xs]


PROFILES = ["o200k", "cl100k", "Qwen/Qwen2.5-7B-Instruct"]


# --- segmentation ------------------------------------------------------------

PROTECTED_RE = re.compile(
    r"^(?P<fence>```|~~~)[^\n]*\n.*?^(?P=fence)[^\n]*$|`[^`\n]+`",
    re.MULTILINE | re.DOTALL,
)
UNIT_RE = re.compile(r"\w+|[^\w\s]|[ \t]+|\r?\n|\s")


@dataclass
class Unit:
    text: str
    protected: bool = False
    ref: str | None = None  # entry key when this unit is a reference

    @property
    def is_space(self) -> bool:
        return self.ref is None and self.text.isspace()

    @property
    def has_newline(self) -> bool:
        return "\n" in self.text


def segment(text: str, protect: bool = True) -> list[Unit]:
    units: list[Unit] = []
    pos = 0
    for m in PROTECTED_RE.finditer(text) if protect else ():
        units += [Unit(u) for u in UNIT_RE.findall(text[pos : m.start()])]
        units.append(Unit(m.group(0), protected=True))
        pos = m.end()
    units += [Unit(u) for u in UNIT_RE.findall(text[pos:])]
    assert "".join(u.text for u in units) == text
    return units


# --- greedy optimizer --------------------------------------------------------


@dataclass
class Result:
    original_tokens: int
    envelope_tokens: int
    payload_tokens: int
    legend_tokens: int
    instruction_tokens: int
    entries: int
    protected_chars: int
    total_chars: int
    seconds: float
    legend: list[tuple[str, str, int]] = field(default_factory=list)

    @property
    def savings(self) -> float:
        return 1 - self.envelope_tokens / self.original_tokens

    @property
    def effective_savings(self) -> float:
        return self.savings if self.savings >= THRESHOLD else 0.0


def opaque_ids(profile: Profile, sigil: str, n: int = 400) -> list[str]:
    """IDs ordered from cheapest to most expensive in context (' §12')."""
    ids = []
    for i in range(n):
        s, x = "", i
        while True:
            s = ID_CHARS[x % 10] + s  # decimal digits only: readable and cheap
            x //= 10
            if not x:
                break
        ids.append(s)
    costs = profile.count_many([f" {sigil}{i}" for i in ids])
    return [i for _, _, i in sorted(zip(costs, map(len, ids), ids))]


def mnemonic(value: str, taken: set[str]) -> str:
    words = re.findall(r"[A-Za-z0-9]+", value)
    base = "".join(w[:4].capitalize() for w in words[:3]) or "X"
    alias, n = base, 1
    while alias in taken:
        n += 1
        alias = f"{base}{n}"  # never collides: aliases are compared as whole IDs
    return alias


def compress(text: str, profile: Profile, notation: str, protect: bool = True) -> Result:
    t0 = time.perf_counter()
    sigil = next(
        (s for s in sorted(SIGIL_CANDIDATES, key=lambda s: profile.count(f" {s}0")) if s not in text),
        None,
    )
    if sigil is None:
        raise ValueError("no free sigil; escaping not implemented in the estimator")

    units = segment(text, protect)
    cheap_ids = opaque_ids(profile, sigil)
    entries: dict[str, str] = {}  # key -> value
    aliases: set[str] = set()
    row_overhead = profile.count(f"{sigil}0=\n") - profile.count(f"{sigil}0")

    while True:
        # Index every word-aligned n-gram of plain, unprotected units.
        index: dict[str, list[int]] = defaultdict(list)
        n = len(units)
        for i in range(n):
            u = units[i]
            if u.protected or u.ref or u.is_space:
                continue
            s = ""
            for j in range(i, min(i + MAX_UNITS, n)):
                v = units[j]
                if v.protected or v.ref or v.has_newline:
                    break
                s += v.text
                if not v.is_space and j > i:
                    index[s].append(i)
        cands = [(s, p) for s, p in index.items() if len(p) >= 2]
        if not cands:
            break

        # Exact non-overlapping occurrence count + gain per candidate.
        t_s_all = profile.count_many([" " + s for s, _ in cands])
        next_id = cheap_ids[len(entries)] if len(entries) < len(cheap_ids) else str(len(entries))
        t_r_default = profile.count(f" {sigil}{next_id}")
        scored = []
        for (s, positions), t_s in zip(cands, t_s_all):
            span = len(UNIT_RE.findall(s))
            if t_s <= t_r_default:
                continue
            occ, last_end = [], -1
            for p in positions:
                end = p + span
                if p < last_end:
                    continue
                nxt = units[end].text[:1] if end < n else ""
                if nxt and nxt in ID_CHARS:
                    continue  # reference boundary rule
                occ.append(p)
                last_end = end
            k = len(occ)
            gain = k * (t_s - t_r_default) - (t_s + row_overhead)
            if gain > 0 and notation == "mnemonic":
                t_r = profile.count(f" {sigil}{mnemonic(s, aliases)}")
                gain = k * (t_s - t_r) - (t_s + row_overhead + t_r - 1)
            if gain > 0:
                scored.append((gain, len(s), s, occ, span))
        if not scored:
            break
        scored.sort(key=lambda x: (-x[0], -x[1], x[2]))

        # Apply up to BATCH candidates whose occurrences don't touch each other.
        touched: set[int] = set()
        applied: list[tuple[str, list[int], int]] = []
        for gain, _, s, occ, span in scored:
            cells = {p + d for p in occ for d in range(span)}
            # Also block neighbours so boundary checks stay valid.
            halo = cells | {p - 1 for p in occ} | {p + span for p in occ}
            if halo & touched:
                continue
            touched |= halo
            applied.append((s, occ, span))
            if len(applied) >= BATCH:
                break

        replacements: dict[int, tuple[int, str]] = {}
        for s, occ, span in applied:
            if notation == "opaque":
                key = f"#{len(entries)}"  # provisional; real IDs assigned at the end
            else:
                key = mnemonic(s, aliases)
                aliases.add(key)
            entries[key] = s
            for p in occ:
                replacements[p] = (span, key)
        new_units, i = [], 0
        while i < n:
            if i in replacements:
                span, key = replacements[i]
                new_units.append(Unit("", ref=key))
                i += span
            else:
                new_units.append(units[i])
                i += 1
        units = new_units

    # Final ID assignment: cheapest IDs to the most frequent entries.
    freq: dict[str, int] = defaultdict(int)
    for u in units:
        if u.ref:
            freq[u.ref] += 1
    order = sorted(entries, key=lambda k: (-freq[k], entries[k]))
    if notation == "opaque":
        final = {k: cheap_ids[i] if i < len(cheap_ids) else str(i) for i, k in enumerate(order)}
    else:
        final = {k: k for k in order}

    payload = "".join(f"{sigil}{final[u.ref]}" if u.ref else u.text for u in units)
    legend_rows = [
        f"{sigil}{final[k]}=" + entries[k].replace("\\", "\\\\") + "\n" for k in order
    ]
    instruction = INSTRUCTION.format(s=sigil)
    legend = "".join(legend_rows)
    envelope = instruction + legend + "---\n" + payload

    # Sanity: expansion must give back the original text.
    lookup = {final[k]: entries[k] for k in order}
    id_re = re.escape(sigil) + r"([0-9A-Za-z]+)"
    assert re.sub(id_re, lambda m: lookup[m.group(1)], payload) == text, "round trip failed"

    original_tokens, envelope_tokens, payload_tokens, legend_tokens, instruction_tokens = (
        profile.count_many([text, envelope, payload, legend, instruction])
    )
    return Result(
        original_tokens=original_tokens,
        envelope_tokens=envelope_tokens,
        payload_tokens=payload_tokens,
        legend_tokens=legend_tokens,
        instruction_tokens=instruction_tokens,
        entries=len(entries),
        protected_chars=sum(len(u.text) for u in segment(text, protect) if u.protected),
        total_chars=len(text),
        seconds=time.perf_counter() - t0,
        legend=[(final[k], entries[k], freq[k]) for k in order],
    )


# --- driver ------------------------------------------------------------------


def pct(xs: list[float], q: float) -> float:
    xs = sorted(xs)
    if len(xs) == 1:
        return xs[0]
    i = q * (len(xs) - 1)
    lo = int(i)
    hi = min(lo + 1, len(xs) - 1)
    return xs[lo] + (xs[hi] - xs[lo]) * (i - lo)


def load_inputs(manifest: dict) -> list[dict]:
    docs = []
    for d in manifest["documents"]:
        docs.append({"name": d["path"], "type": d["type"], "text": (ROOT / d["path"]).read_text("utf-8")})
    for b in manifest["bundles"]:
        if b.get("from_documents"):
            paths = [d["path"] for d in manifest["documents"]]
        else:
            paths = sorted(str(Path(p).relative_to(ROOT)) for p in glob.glob(str(ROOT / b["glob"])))
        text = "\n\n".join((ROOT / p).read_text("utf-8") for p in paths)
        docs.append({"name": b["name"], "type": "bundle", "text": text, "members": len(paths)})
    return docs


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "feasibility" / "results"))
    ap.add_argument("--variants", default="opaque,mnemonic,opaque-unprotected")
    args = ap.parse_args()

    manifest = json.loads((ROOT / "feasibility" / "corpus.json").read_text())
    inputs = load_inputs(manifest)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    rows = []
    for pname in PROFILES:
        profile = Profile(pname)
        for notation in args.variants.split(","):
            for doc in inputs:
                r = compress(
                    doc["text"], profile, notation.removesuffix("-unprotected"),
                    protect=not notation.endswith("-unprotected"),
                )
                rows.append(
                    {
                        "doc": doc["name"],
                        "type": doc["type"],
                        "profile": pname,
                        "notation": notation,
                        "original_tokens": r.original_tokens,
                        "envelope_tokens": r.envelope_tokens,
                        "payload_tokens": r.payload_tokens,
                        "legend_tokens": r.legend_tokens,
                        "instruction_tokens": r.instruction_tokens,
                        "savings": round(r.savings, 4),
                        "effective_savings": round(r.effective_savings, 4),
                        "entries": r.entries,
                        "protected_share": round(r.protected_chars / r.total_chars, 4),
                        "seconds": round(r.seconds, 2),
                        "top_entries": r.legend[:8],
                    }
                )
                print(
                    f"{pname:>26} {notation:>8} {doc['name'][-44:]:>44} "
                    f"{r.original_tokens:>7} -> {r.envelope_tokens:>7}  {r.savings:+.1%}  "
                    f"({r.entries} entries, {r.seconds:.1f}s)",
                    flush=True,
                )

    (out / "estimate.json").write_text(json.dumps(rows, indent=1, ensure_ascii=False))
    (out / "estimate.md").write_text(report(rows))
    print(f"\nwrote {out / 'estimate.md'}")


def report(rows: list[dict]) -> str:
    lines = ["# Phase 0 — savings estimate", ""]
    lines += [
        "Savings = 1 − envelope / original, where the envelope is instruction + legend + payload.",
        f"Effective savings apply the {THRESHOLD:.0%} passthrough threshold.",
        "",
        "## Single documents (pilot corpus, n=20)",
        "",
        "| Profile | Variant | Median | p10 | p90 | Median effective | Docs ≥ 10% |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    groups: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for r in rows:
        if r["type"] != "bundle":
            groups[(r["profile"], r["notation"])].append(r)
    for (p, nt), rs in groups.items():
        s = [r["savings"] for r in rs]
        e = [r["effective_savings"] for r in rs]
        lines.append(
            f"| {p} | {nt} | {statistics.median(s):.1%} | {pct(s, .1):.1%} | {pct(s, .9):.1%} "
            f"| {statistics.median(e):.1%} | {sum(x >= .10 for x in s)}/{len(s)} |"
        )

    lines += ["", "## By document type (median savings, opaque notation)", ""]
    profiles = list(dict.fromkeys(r["profile"] for r in rows))
    lines += ["| Type | " + " | ".join(profiles) + " |", "| --- |" + " --- |" * len(profiles)]
    types = sorted({r["type"] for r in rows})
    for t in types:
        cells = []
        for p in profiles:
            s = [r["savings"] for r in rows if r["type"] == t and r["profile"] == p and r["notation"] == "opaque"]
            cells.append(f"{statistics.median(s):.1%}" if s else "–")
        lines.append(f"| {t} | " + " | ".join(cells) + " |")

    lines += ["", "## Per document (opaque notation)", ""]
    lines += [
        "| Document | Type | " + " | ".join(profiles) + " | Entries (o200k) | Protected |",
        "| --- | --- |" + " --- |" * len(profiles) + " --- | --- |",
    ]
    for d in dict.fromkeys(r["doc"] for r in rows):
        rs = {r["profile"]: r for r in rows if r["doc"] == d and r["notation"] == "opaque"}
        first = next(iter(rs.values()))
        lines.append(
            f"| {d.removeprefix('test_docs/')} | {first['type']} | "
            + " | ".join(f"{rs[p]['savings']:+.1%}" for p in profiles)
            + f" | {rs[profiles[0]]['entries']} | {first['protected_share']:.0%} |"
        )

    lines += ["", "## Envelope breakdown (o200k, opaque, totals over the 20 documents)", ""]
    rs = [r for r in rows if r["profile"] == profiles[0] and r["notation"] == "opaque" and r["type"] != "bundle"]
    if rs:
        tot = lambda k: sum(r[k] for r in rs)  # noqa: E731
        lines += [
            "| Original | Instruction | Legend | Payload | Envelope |",
            "| --- | --- | --- | --- | --- |",
            f"| {tot('original_tokens')} | {tot('instruction_tokens')} | {tot('legend_tokens')} "
            f"| {tot('payload_tokens')} | {tot('envelope_tokens')} |",
        ]
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    main()
