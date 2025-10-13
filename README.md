# c_CTRL-O.vim

_One-shot normal mode for command-line mode_

## Overview

This plugin introduces a natural analogue to insert-mode `CTRL-O` for command-line mode. When partway through writing a command-line or performing an incremental search with `CTRL-G` and `CTRL-T`, you might:

- Redraw the screen with `CTRL-O CTRL-L`.
- Peek at what function or section you're in with `CTRL-O [[`.
- Peek at the definition for the current match with `CTRL-O gd`, `CTRL-O gD`, `CTRL-O [ CTRL-I`, etc.
- Scroll around with `CTRL-O zt`, `CTRL-O CTRL-D`, `CTRL-O zL`, etc.
- Perform a nested search with `CTRL-O /{pattern}<CR>`, then peek at subsequent matches with `CTRL-O n`.
- Execute nested command-lines like `CTRL-O :se {option}<CR>`, `CTRL-O :w<CR>`, etc.

## Mappings

**Command-line `CTRL-O`** — Execute one normal-mode command then return to command-line mode. The command is performed under textlock. Works like insert-mode `CTRL-O`.

**Command-line `CTRL-\ CTRL-O`** — Abandon the command-line, go to normal mode without moving the cursor. This differs from command-line `CTRL-C` and `<CR>` during an incremental search, after using command-line `CTRL-O` to move the cursor off of the latest match.

- `CTRL-C` — Jumps to the original cursor position.
- `<CR>` — Jumps to the latest match.
- `CTRL-\ CTRL-O` — Does not move the cursor.

The jumplist is updated with the original cursor position.

**Command-line `CTRL-R CTRL-O {motion}`** — Insert `{motion}` text into the command-line as if typed. The text is also put into the unnamed register.

**Command-line `CTRL-R CTRL-R CTRL-O {motion}`** — Insert `{motion}` text into the command-line literally. The text is also put into the unnamed register. Works like command-line `CTRL-R CTRL-O {motion}` but inserts the text literally.
