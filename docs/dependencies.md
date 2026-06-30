---
layout: default
title: Dependencies
prev_page:
  title: Installation
  url: /installation.html
next_page:
  title: Tools
  url: /tools.html
toc:
  - title: Dependencies
    href: "#dependencies"
  - title: Notes
    href: "#notes"
---

# Dependencies

- <a href="https://www.reaper.fm/" target="_blank" rel="noopener noreferrer">REAPER</a>
- <a href="https://codeberg.org/cfillion/reaimgui" target="_blank" rel="noopener noreferrer">ReaImGui</a>
  for the browser and controller scripts
- <a href="https://www.python.org/downloads/" target="_blank" rel="noopener noreferrer">Python 3</a>
  with <a href="https://numpy.org/install/" target="_blank" rel="noopener noreferrer">NumPy</a>
  for NumPy-backed offline processes
- <a href="https://github.com/espeak-ng/espeak-ng" target="_blank" rel="noopener noreferrer">eSpeak NG</a>
  for `EVP Field` only
- <a href="https://leomccormack.github.io/sparta-site/" target="_blank" rel="noopener noreferrer">SPARTA plugins</a>
  for the 3OA workflow

## Notes

ReaImGui is available through ReaPack's default ReaTeam Extensions repository.

For NumPy-backed processes, use WAV-backed media. Convert compressed source
files to WAV before analysis or rendering.

eSpeak NG is only required by `EVP Field` at this point. On macOS, it can be
installed with Homebrew:

```sh
brew install espeak-ng
```

If REAPER cannot find eSpeak NG after installation, put an
`espeak_ng_path.txt` file beside the scripts containing the full path to the
binary, for example `/opt/homebrew/bin/espeak-ng`.

SPARTA source and releases are available at
<a href="https://github.com/leomccormack/SPARTA" target="_blank" rel="noopener noreferrer">leomccormack/SPARTA</a>.
