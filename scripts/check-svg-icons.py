#!/usr/bin/env python3
"""Check monochrome icons for transparent canvas shapes affected by tinting."""

import argparse
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = "entry/src/main/resources"


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT).decode("utf-8")


def is_canvas(element, view_box):
    tag = element.tag.rsplit("}", 1)[-1]
    if tag == "rect":
        bounds = [float(element.get(key, "0")) for key in ("x", "y", "width", "height")]
        return bounds == view_box
    if tag == "path" and view_box == [0.0, 0.0, 24.0, 24.0]:
        # shortcut: covers Material's current canvas paths; extend for new export formats.
        data = re.sub(r"[\s,]+", "", element.get("d", ""))
        return data == "M2424H0V0h24v24z" or bool(
            re.fullmatch(r"M00h24v24H0V0z(?:m00h24v24H0V0z)*", data)
        )
    return False


def inspect_svg(source):
    root = ET.fromstring(source)
    view_box = [float(value) for value in root.get("viewBox", "").split()]
    hazards = 0
    visible_paths = 0

    def walk(element, inherited):
        nonlocal hazards, visible_paths
        style = dict(inherited)
        style.update(element.attrib)
        style["opacity"] = float(inherited.get("opacity", 1)) * float(element.get("opacity", 1))
        fill_visible = style.get("fill", "black") != "none" and float(style.get("fill-opacity", 1)) > 0
        stroke_visible = style.get("stroke", "none") != "none" and float(style.get("stroke-opacity", 1)) > 0
        visible = style["opacity"] > 0 and (fill_visible or stroke_visible)
        tag = element.tag.rsplit("}", 1)[-1]
        if tag == "path" and element.get("d") and visible:
            visible_paths += 1
        if is_canvas(element, view_box) and not visible:
            hazards += 1
        for child in element:
            walk(child, style)

    walk(root, {})
    return hazards, visible_paths


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--git-ref", help="Inspect a committed revision instead of the working tree")
    args = parser.parse_args()
    names = {}
    errors = []
    hazard_count = 0
    for theme in ("base", "dark"):
        directory = f"{RESOURCE}/{theme}/media"
        if args.git_ref:
            paths = [path for path in git("ls-tree", "-r", "--name-only", args.git_ref, directory).splitlines()
                     if Path(path).name.startswith("icon_") and path.endswith(".svg")]
        else:
            paths = [path.relative_to(ROOT).as_posix() for path in sorted((ROOT / directory).glob("icon_*.svg"))]
        names[theme] = {Path(path).name for path in paths}
        for path in paths:
            source = git("show", f"{args.git_ref}:{path}") if args.git_ref else (ROOT / path).read_text(encoding="utf-8")
            hazards, visible_paths = inspect_svg(source)
            hazard_count += hazards
            if hazards or not visible_paths:
                errors.append(f"{path}: {hazards} transparent canvas shape(s), {visible_paths} visible path(s)")
    if not names["base"] or names["base"] != names["dark"]:
        errors.append("Light and dark icon names must be nonempty and paired")
    label = args.git_ref or "working tree"
    print(f"{label}: {len(names['base']) + len(names['dark'])} icons, {hazard_count} transparent canvas shapes")
    for error in errors:
        print(error)
    return bool(errors)


if __name__ == "__main__":
    sys.exit(main())
