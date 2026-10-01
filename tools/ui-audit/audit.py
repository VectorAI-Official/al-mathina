#!/usr/bin/env python3
"""
UI safety audit for the AL-Madhina admin web UI (zero-dependency, Python stdlib only).

Run from the repo root:

    python3 tools/ui-audit/audit.py            # full report
    python3 tools/ui-audit/audit.py --snapshot # write baseline snapshot (run before changes)
    python3 tools/ui-audit/audit.py --check    # compare against baseline, fail on drift

Checks
  1. selector-ids     every id queried from JS still exists in the HTML that loads that JS
  2. selector-classes every class queried/toggled from JS still exists in the HTML or CSS
  3. duplicate-ids    no HTML file contains the same id twice (getElementById returns the first)
  4. tag-balance      every edited HTML file has balanced <div>/<form>/<table>/<section> nesting
  5. asset-versions   every /static/... href|src carries a ?v= cache-buster
  6. head-order       shared stylesheets load before page stylesheets (cascade order R1)
  7. inline-display   count of inline display:none/flex/block toggles (must not drop)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ADMIN = os.path.join(ROOT, "go-backend", "static", "admin")
STATIC = os.path.join(ROOT, "go-backend", "static")
SNAPSHOT = os.path.join(os.path.dirname(__file__), "snapshot.json")

# page -> ordered list of local js files it loads
PAGE_JS = {
    "dashboard.html": ["js/dashboard.js", "js/imageConverter.js"],
    "inventory.html": ["js/inventory.js"],
    "orders.html": ["js/orders.js"],
    "stores.html": ["js/stores.js"],
}

SHARED_CSS = ("theme.css", "components.css")

VOID_TAGS = {
    "area", "base", "br", "col", "embed", "hr", "img", "input",
    "link", "meta", "param", "source", "track", "wbr",
}

TRACKED_TAGS = ("div", "form", "table", "section", "nav", "header", "tbody", "thead")

# ---------------------------------------------------------------- utilities

def read(path: str) -> str:
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()


def admin_pages() -> list[str]:
    out = []
    for name in sorted(os.listdir(ADMIN)):
        if name.endswith(".html"):
            out.append(os.path.join(ADMIN, name))
    for name in sorted(os.listdir(STATIC)):
        if name.endswith(".html"):
            out.append(os.path.join(STATIC, name))
    return out


def strip_html_noise(html: str) -> str:
    """Remove <script>/<style>/comments so string scanning sees only markup.

    Blanked regions keep their newline count so reported line numbers stay true.
    """
    def blank(m: re.Match) -> str:
        return re.sub(r"[^\n]", " ", m.group(0))

    html = re.sub(r"<script\b[^>]*>.*?</script>", blank, html, flags=re.S | re.I)
    html = re.sub(r"<style\b[^>]*>.*?</style>", blank, html, flags=re.S | re.I)
    html = re.sub(r"<!--.*?-->", blank, html, flags=re.S)
    return html


# ---------------------------------------------------------------- 1 & 2: selectors

RE_ID_QUERIES = [
    re.compile(r"""getElementById\(\s*['"]([^'"]+)['"]"""),
    re.compile(r"""\$\(\s*['"]#([A-Za-z_][\w:-]*)['"]\s*\)"""),
]
RE_CLASS_QUERIES = [
    re.compile(r"""querySelector(?:All)?\(\s*['"]([^'"]+)['"]"""),
    re.compile(r"""getElementsByClassName\(\s*['"]([^'"]+)['"]"""),
    re.compile(r"""\$\(\s*['"]\.([A-Za-z_][\w-]*)['"]\s*\)"""),
]
RE_CLASSLIST = re.compile(r"""classList\.(?:add|remove|toggle|contains)\(\s*['"]([A-Za-z_][\w-]*)['"]""")
RE_CLASSNAME = re.compile(r"""className\s*=\s*['"]([^'"]*)['"]""")
RE_ONCLICK_CLASS = re.compile(r"""class="([^"]*)""")

# ids/classes injected at runtime through innerHTML templates or setAttribute
RE_JS_ID_ATTR = re.compile(r"""\bid\s*=\s*['"]([A-Za-z_][\w:-]*)['"]""")
RE_JS_SETATTR = re.compile(r"""setAttribute\(\s*['"](id|class)['"]\s*,\s*['"]([^'"]+)['"]""")


def simple_selectors(css: str) -> set[str]:
    """Class names referenced from a selector, ignoring at-rules/pseudo/nesting."""
    css = re.sub(r"/\*.*?\*/", " ", css, flags=re.S)
    out: set[str] = set()
    for sel in re.findall(r"([^{}]+)\{", css):
        if sel.strip().startswith("@"):
            continue
        for part in sel.split(","):
            for cl in re.findall(r"\.([A-Za-z_][\w-]*)", part):
                out.add(cl)
    return out


def collect_state() -> dict:
    pages = admin_pages()
    html_by_name = {os.path.basename(p): read(p) for p in pages}
    markup_by_name = {n: strip_html_noise(h) for n, h in html_by_name.items()}

    html_ids: dict[str, set[str]] = {}
    html_classes: dict[str, set[str]] = {}
    for name, markup in markup_by_name.items():
        html_ids[name] = set(re.findall(r"""\bid\s*=\s*['"]([^'"]+)['"]""", markup))
        classes: set[str] = set()
        for attr in re.findall(r"""\bclass\s*=\s*['"]([^'"]*)['"]""", markup):
            classes.update(c for c in attr.split() if c)
        html_classes[name] = classes

    css_classes: set[str] = set()
    css_dir = os.path.join(ADMIN, "css")
    if os.path.isdir(css_dir):
        for name in os.listdir(css_dir):
            if name.endswith(".css"):
                css_classes |= simple_selectors(read(os.path.join(css_dir, name)))

    # ids referenced from each page's own JS, plus ids that JS injects itself
    missing_ids: dict[str, list[str]] = {}
    missing_classes: dict[str, list[str]] = {}
    latent_ids: dict[str, list[str]] = {}
    referenced_ids: set[str] = set()
    referenced_classes: set[str] = set()

    for page, js_files in PAGE_JS.items():
        ids: set[str] = set()
        classes: set[str] = set()
        js_created: set[str] = set()
        for rel in js_files:
            js = read(os.path.join(ADMIN, rel))
            for rx in RE_ID_QUERIES:
                ids |= set(rx.findall(js))
            for rx in RE_CLASS_QUERIES + [RE_CLASSLIST, RE_CLASSNAME]:
                for group in rx.findall(js):
                    if rx is RE_CLASSNAME:
                        classes.update(c for c in group.split() if c)
                    else:
                        classes.update(simple_selectors(group))
            js_created |= set(RE_JS_ID_ATTR.findall(js))
            for kind, val in RE_JS_SETATTR.findall(js):
                (js_created if kind == "id" else classes).add(val)
        referenced_ids |= ids
        referenced_classes |= classes
        miss_i = sorted(i for i in ids if i not in html_ids[page])
        unknown = [i for i in miss_i if i not in js_created]
        # queried but produced nowhere and present in no page at all -> latent bug
        global_ids = set().union(*html_ids.values())
        lat = [i for i in unknown if i not in global_ids]
        if unknown:
            missing_ids[page] = unknown
        if lat:
            latent_ids[page] = sorted(lat)
        miss_c = sorted(c for c in classes if c not in html_classes[page] and c not in css_classes)
        if miss_c:
            missing_classes[page] = miss_c

    # login page: inline <script> only
    for page in ("login.html",):
        js_ids = set()
        for rx in RE_ID_QUERIES:
            js_ids |= set(rx.findall(html_by_name[page]))
        miss = sorted(i for i in js_ids if i not in html_ids[page])
        if miss:
            missing_ids[page] = miss
        referenced_ids |= js_ids

    return {
        "html_ids": {k: sorted(v) for k, v in html_ids.items()},
        "html_classes": {k: sorted(v) for k, v in html_classes.items()},
        "css_classes": sorted(css_classes),
        "referenced_ids": sorted(referenced_ids),
        "referenced_classes": sorted(referenced_classes),
        "missing_ids": missing_ids,
        "missing_classes": missing_classes,
        "latent_ids": latent_ids,
    }


# ---------------------------------------------------------------- 3: duplicate ids

def collect_duplicate_ids() -> dict[str, list[str]]:
    dupes: dict[str, list[str]] = {}
    for name, markup in ((os.path.basename(p), strip_html_noise(read(p))) for p in admin_pages()):
        counts: dict[str, int] = defaultdict(int)
        for i in re.findall(r"""\bid\s*=\s*['"]([^'"]+)['"]""", markup):
            counts[i] += 1
        d = sorted(i for i, c in counts.items() if c > 1)
        if d:
            dupes[name] = d
    return dupes


# ---------------------------------------------------------------- 4: tag balance

def check_tag_balance(path: str) -> list[str]:
    """Verify nesting of container elements only. Self-closing/void/untracked tags are ignored."""
    src = strip_html_noise(read(path))
    problems: list[str] = []
    stack: list[tuple[str, int]] = []
    for m in re.finditer(r"<(/?)([a-zA-Z]+)((?:[^>\"']|\"[^\"]*\"|'[^']*')*?)(/?)>", src):
        closing, tag, _attrs, selfclose = m.group(1), m.group(2).lower(), m.group(3), m.group(4)
        if tag not in TRACKED_TAGS or tag in VOID_TAGS or selfclose:
            continue
        line = src.count("\n", 0, m.start()) + 1
        if closing:
            if not stack:
                problems.append(f"line {line}: stray </{tag}>")
            elif stack[-1][0] != tag:
                problems.append(
                    f"line {line}: </{tag}> closes <{stack[-1][0]}> opened at line {stack[-1][1]}"
                )
                stack.pop()
            else:
                stack.pop()
        else:
            stack.append((tag, line))
    for tag, line in stack:
        problems.append(f"line {line}: <{tag}> never closed")
    return problems


# ---------------------------------------------------------------- 5: asset versions

def collect_assets() -> dict[str, list[str]]:
    """page -> local asset urls lacking a ?v= cache-buster."""
    stale: dict[str, list[str]] = {}
    for path in admin_pages():
        name = os.path.basename(path)
        html = read(path)
        urls: list[str] = []
        for attr in re.findall(r"""\b(?:href|src)\s*=\s*['"]([^'"]+)['"]""", html):
            if attr.startswith("/static/") or attr.startswith("static/"):
                if "?v=" not in attr:
                    urls.append(attr)
        if urls:
            stale[name] = sorted(set(urls))
    return stale


def collect_existing_assets() -> dict[str, list[str]]:
    """page -> every local asset url with its version (or 'UNVERSIONED')."""
    out: dict[str, list[str]] = {}
    for path in admin_pages():
        html = read(path)
        found = []
        for attr in re.findall(r"""\b(?:href|src)\s*=\s*['"]([^'"]+)['"]""", html):
            if attr.startswith("/static/"):
                found.append(attr)
        out[os.path.basename(path)] = sorted(set(found))
    return out


# ---------------------------------------------------------------- 6: cascade order

def check_head_order() -> dict[str, list[str]]:
    """Shared (ui-*) stylesheets must be linked before page stylesheets."""
    bad: dict[str, list[str]] = {}
    for path in admin_pages():
        name = os.path.basename(path)
        html = read(path)
        head = re.search(r"<head\b.*?</head>", html, flags=re.S | re.I)
        if not head:
            continue
        order = re.findall(r"""\bhref\s*=\s*['"]([^'"]+\.css[^'"]*)['"]""", head.group(0))
        shared = [i for i, u in enumerate(order) if any(s in u for s in SHARED_CSS)]
        pages = [i for i, u in enumerate(order) if any(p in u for p in ("dashboard.css", "orders.css", "stores.css", "inventory.css", "login.css", "privacy.css"))]
        if shared and pages and max(shared) > min(pages):
            bad[name] = order
    return bad


# ---------------------------------------------------------------- 7: inline display toggles

def collect_inline_display() -> dict[str, dict[str, int]]:
    counts: dict[str, dict[str, int]] = {}
    for path in admin_pages():
        html = read(path)
        n = {}
        for val in ("none", "flex", "block", "grid", "inline", "inline-flex"):
            n[val] = len(re.findall(r"""style\s*=\s*["'][^"']*display\s*:\s*%s""" % val, html))
        if any(n.values()):
            counts[os.path.basename(path)] = n
    return counts


# ---------------------------------------------------------------- report

def snapshot() -> dict:
    return {
        "referenced_ids": sorted(set(collect_state()["referenced_ids"])),
        "html_ids": collect_state()["html_ids"],
        "html_classes": collect_state()["html_classes"],
        "inline_display": collect_inline_display(),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", action="store_true", help="write baseline snapshot")
    ap.add_argument("--check", action="store_true", help="diff against baseline, exit 1 on drift")
    ap.add_argument("--changed", nargs="*", default=[], help="only tag-balance these files")
    args = ap.parse_args()

    if args.snapshot:
        with open(SNAPSHOT, "w", encoding="utf-8") as fh:
            json.dump(snapshot(), fh, indent=2, sort_keys=True)
        print(f"snapshot written -> {os.path.relpath(SNAPSHOT, ROOT)}")
        return 0

    state = collect_state()
    dupes = collect_duplicate_ids()
    stale = collect_assets()
    head_bad = check_head_order()
    displays = collect_inline_display()

    print("=" * 72)
    print("1. JS -> HTML selector integrity")
    print(f"   ids referenced by JS      : {len(state['referenced_ids'])}")
    if state["missing_ids"]:
        for page, ids in state["missing_ids"].items():
            print(f"   {page}: {len(ids)} id(s) not in static markup (must exist in its own JS)")
    else:
        print("   missing ids                : none")
    if state.get("latent_ids"):
        for page, ids in state["latent_ids"].items():
            print(f"   LATENT (pre-existing) in {page}: {', '.join(ids)}")
    if state["missing_classes"]:
        for page, cls in state["missing_classes"].items():
            print(f"   unresolved classes in {page}: {', '.join(cls)}")
    else:
        print("   unresolved classes          : none")

    print()
    print("2. duplicate ids (getElementById returns only the first)")
    for page, ids in dupes.items():
        print(f"   {page}: {', '.join(ids)}")
    if not dupes:
        print("   none")

    print()
    print("3. tag balance")
    targets = args.changed or [p for p in admin_pages()]
    any_bad = False
    for path in targets:
        problems = check_tag_balance(path)
        if problems:
            any_bad = True
            print(f"   {os.path.relpath(path, ROOT)}")
            for p in problems[:10]:
                print(f"      {p}")
    if not any_bad:
        print("   all balanced")

    print()
    print("4. asset cache-busters (/static/* is served immutable for 1 year)")
    if stale:
        for page, urls in stale.items():
            print(f"   UNVERSIONED {page}: {', '.join(urls)}")
    else:
        print("   all local assets versioned")

    print()
    print("5. cascade order (shared css before page css)")
    if head_bad:
        for page, order in head_bad.items():
            print(f"   {page}: {order}")
    else:
        print("   correct")

    print()
    print("6. inline style.display toggles (JS-driven; must not decrease)")
    for page, n in sorted(displays.items()):
        print(f"   {page}: {n}")

    print()
    print("=" * 72)

    if args.check:
        base = json.loads(read(SNAPSHOT))
        problems = []
        now = snapshot()
        for page, ids in now["html_ids"].items():
            was = set(base["html_ids"].get(page, []))
            lost = sorted(was - set(ids))
            if lost:
                problems.append(f"{page}: ids removed -> {lost}")
        for page, n in now["inline_display"].items():
            was = base["inline_display"].get(page, {})
            for key, val in n.items():
                if val < was.get(key, 0):
                    problems.append(f"{page}: inline display:{key} dropped {was[key]} -> {val}")
        if problems:
            print("DRIFT DETECTED:")
            for p in problems:
                print("  - " + p)
            return 1
        print("No drift vs snapshot. Baseline preserved.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
