# dired-fdclone.el

This package includes functions and settings for dired to make it work
and feel like the legendary file manager
[FD](http://ja.wikipedia.org/wiki/FD_%28%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E7%AE%A1%E7%90%86%E3%82%BD%E3%83%95%E3%83%88%29),
or its portable clone called
[FDclone](http://hp.vector.co.jp/authors/VA012337/soft/fd/).

It also implements some original features to make it even more useful.

## Functions

dired-fdclone.el provides the following interactive commands:

* diredfd-goto-top
* diredfd-goto-bottom
* diredfd-toggle-mark-here
* diredfd-toggle-mark
* diredfd-toggle-all-marks
* diredfd-mark-or-unmark-all
* diredfd-unmark-all-marks
* diredfd-narrow-to-marked-files
* diredfd-narrow-to-files-regexp
* diredfd-goto-filename
* diredfd-do-shell-command
* diredfd-do-sort
* diredfd-do-flagged-delete-or-execute
* diredfd-enter
* diredfd-enter-directory
* diredfd-enter-parent-directory
* diredfd-enter-root-directory
* diredfd-history-backward
* diredfd-history-forward
* diredfd-follow-symlink
* diredfd-do-pack
* diredfd-do-rename
* diredfd-do-unpack
* diredfd-help
* diredfd-nav-mode

## Installation

This package is available on [MELPA](http://melpa.org/).

## Configuration

The above functions are mostly usable stand-alone, but if you feel
like _omakase_, add the following line to your setup.

```elisp
(dired-fdclone)
```

This makes dired:

- color directories in cyan and symlinks in yellow like FDclone
- sort directory listings in the directory-first style
- alter key bindings to mimic FD/FDclone
- not open a new buffer when you navigate to a new directory
- run a shell command in ansi-term to allow launching interactive
  commands
- automatically revert the buffer after running a command with obvious
  side-effects
- automatically add visited files to `file-name-history` (customizable)

Without spoiling dired's existing features.

As usual, customization is available via:

    M-x customize-group dired-fdclone RET

## Author

Copyright (c) 2014-2023 Akinori MUSHA.

Licensed under the 2-clause BSD license.  See `LICENSE.txt` for
details.

Visit the [GitHub Repository](https://github.com/knu/dired-fdclone.el)
for the latest information.
