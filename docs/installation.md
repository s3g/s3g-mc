---
layout: default
title: Installation
prev_page:
  title: Overview
  url: /
next_page:
  title: Dependencies
  url: /dependencies.html
toc:
  - title: Installation
    href: "#installation"
  - title: Package Browser Shortcut
    href: "#package-browser-shortcut"
  - title: Python Path
    href: "#python-path"
---

# Installation

Copy or symlink the package folders into your REAPER resource path:

```text
Scripts/s3g-mc -> REAPER/Scripts/s3g-mc
Effects/s3g    -> REAPER/Effects/s3g
```

In REAPER:

1. Open `Actions > Show action list...`.
2. Click `New Action > Load ReaScript...`.
3. Choose `REAPER/Scripts/s3g-mc/s3g-mc Package Browser.lua`.
4. Run `s3g-mc Package Browser`.
5. Click `Install/refresh actions` in the browser.

If the JSFX do not appear, rescan JSFX or restart REAPER.

## Package Browser Shortcut

To keep the package browser available from REAPER without opening the Action
List each time:

1. Open `Options > Customize menus/toolbars...`.
2. Choose where the browser should live, such as `Main actions` or a custom menu.
3. Click `Add...`.
4. Search for `s3g-mc Package Browser`, select the action, and confirm.
5. Save the menu or toolbar changes.

The same approach can also be used for any individual s3g-mc action you use often.

## Python Path

Some offline tools require Python 3 with NumPy. If REAPER cannot find the
intended Python, put a file named `python3_path.txt` beside the scripts:

```text
REAPER/Scripts/s3g-mc/python3_path.txt
```

The file should contain only the full path to `python3`.
