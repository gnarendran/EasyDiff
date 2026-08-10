# EasyDiff

**EasyDiff** provides a simplified keyboard interface for resolving two-way diffs in Vim and Neovim. It abstracts Vim's mnemonic diff commands behind an intuitive cursor-key interface, simplifying navigation within and between diffs and making repetitive merge, delete, and undo operations faster.

---
## Features
* Provides intuitive merge, delete (both one-sided and two-sided), and undo of Diffs using `<Left>`, `<Right>`, `<Delete>`, `<S-Delete>`, `<Backspace>` keys.
* Supports navigation within a Diff (Start, End of a Diff) with `<PageUp>`, `<PageDown>` keys
* Supports navigation between Diffs (First, Last, Previous, Next) with `<Home>`, `<End>`, `<Up>`, `<Down>` keys.
* The keys are context aware; for example, regardless of whether the cursor is in the left or right window, `<Right>` will merge the Diff from the left window to the right. Similarly, `<Backspace>` undoes the merges and deletes across the two windows, independent of whether the window is left or right. `<Backspace>` atomically undoes two-sided deletes performed with `<S-Delete>`.
* Handles all possible configurations of Diffs. When the cursor line represents multiple Diffs (previous filler, change/added or EOF filler), the user is prompted to determine the target Diff for merge/delete operations.
* Automatically adapts to diffopt+=linematch:{n}, handling both grouped and split diffs transparently.
* The movement keys are enabled in visual mode as well. For example, one can select (visual) a Diff with `<PageUp>V<PageDown>`

---
## Installation

1. Download `EasyDiff.vim`.
2. Place `EasyDiff.vim` into the plugin directory (e.g., `~/.vim/plugin/` or `~/.config/nvim/plugin/`), or source it directly in the Vim startup file (`.vimrc` or `init.vim`):

```vim
source /path/to/EasyDiff.vim
```
---

## Requirements

* Requires Vim 9.2 or Neovim 0.11.6 (the tested versions). EasyDiff might work in lower versions, but any issues found in lower versions are out of scope of this plugin.
* Requires **exactly two vertically split windows**, both in diff mode. Diffs may be opened directly using `vim -d`, `nvim -d`, or `vimdiff`, or by manually invoking `:diffthis` in both vertical splits.
* Requires the default diff options `set cursorbind` and `set diffopt+=filler` to remain unmodified.
---

## Key Bindings

| Key | Action |
| :--- | :--- |
| `<Right>` | Merge current Diff from the **left** window to the **right** window |
| `<Left>` | Merge current Diff from the **right** window to the **left** window |
| `<Delete>` | Delete the current Diff in the current window |
| `<S-Delete>` | Delete the current Diff in both windows |
| `<Backspace>` | Undo the last merge or delete |
| `<Home>` | Jump to the **first** Diff |
| `<End>` | Jump to the **last** Diff |
| `<Up>` | Jump to the **previous** Diff *(accepts count)* |
| `<Down>` | Jump to the **next** Diff *(accepts count)* |
| `<PageUp>` | Jump to the **start** of the current Diff |
| `<PageDown>` | Jump to the **end** of the current Diff |
| `<S-Home>` | Move cursor to the other window |
| `<F1>` | Print help message |

> **Notes on Bindings:**
> * These keybindings are restricted to the two diffed buffers.
> * A **Diff** is a contiguous region identified by Vim's diff engine. It may consist of one or more changed, added, or filler regions. For example, to delete lines in the right window that correspond to filler lines in the left window, simply press `<Right>`. EasyDiff automatically executes `dp` (or `do` from the right window) to produce the expected result.
> * `<Delete>` deletes the Diff **only** in the current window. If the deleted Diff is adjacent to an existing Filler, Vim/Neovim merges the new and existing Fillers into a single, larger Diff. Then the new larger Diff may be merged with the other window using `<Left>` or `<Right>`.
> * `<S-Delete>` first finds the full extent of the Diff in current window, including any Filler. Then it deletes this extent from **both** windows.
> * `<Backspace>` undoes both the deletes performed by `<S-Delete>` in the two windows, at once. To only undo one of those deletes, one has to manually undo using 'u', but that will reset EasyDiff's undo tracking.
> * `<S-End>` or `2<End>` toggles 'linematch' diffopt; `3<End>` toggles centering with 'scrolloff=999'; `4<End>` toggles numbering the lines with 'number'
> * `<Home>` jumps to the first Diff. At start, the cursor is automatically placed on the first Diff in the left window.
> * `<S-Home>` Moves cursor to the corresponding line in the other window; once there, moves cursor as per variable g:easydiff_stay_on_diff. Vim/Neovim's native <C-w>w could instead be used to switch windows without readjusting the cursor position.
> * If the terminal does not support the shifted keys `<S-Delete>`, `<S-Home>`, or `<S-End>`, alternatives `2<Delete>`, `2<Home>`, `2<End>` may be used.
---

## Configuration Variables

### `g:easydiff_stay_on_diff`

Controls cursor positioning after an edit or window switch:

```vim
let g:easydiff_stay_on_diff = 1
```
* **`(Default)`**: After a Diff merge, delete, undo, or window switch, keep the cursor on a Diff: if it is not already on a Diff, move it to the next Diff; if there is no next Diff, move it to the last Diff.

```vim
let g:easydiff_stay_on_diff = 0
```
* After a Diff merge, delete, undo or window switch, no attempt is made to keep the cursor on a Diff.

---

## Limitations

* **Edit Tracking & Undo:** EasyDiff tracks edits (merges/deletes) performed using `<Right>`, `<Left>`, `<Delete>` or `<S-Delete>`, allowing them to be repeatedly undone using `<Backspace>`. **Note:** Performing any manual edit will reset this edit tracking.
* **Custom Mappings:** The default key bindings may not suit all workflows. Mappings can be customized inside `s:DiffModeSetup()`.
* Due to an upstream Vim/Neovim rendering quirk, an EOF filler may not be visible by default even though EasyDiff tracks it correctly; press `<C-e>` to reveal it.
