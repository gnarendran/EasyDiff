# EasyDiff

**EasyDiff** provides a simplified keyboard interface for resolving diffs in Vim and Neovim. It abstracts Vim's mnemonic diff commands behind an intuitive cursor-key interface, simplifying navigation within and between diffs and making repetitive merge, delete, and undo operations faster.

---
## Features
> Below the default key mappings for the commands are shown in brackets. They may be disabled and alternative mappings may be setup.
* Provides intuitive merge, delete (in current or in all diff windows) of Diffs, and globally tracked undo of the operations, using the commands `EasyDiffMergeDiffLeft` (`<Left>`), `EasyDiffMergeDiffRight` (`<Right>`), `EasyDiffDeleteDiffInCurrentWindow` (`<Delete>`), `EasyDiffDeleteDiffInAllWindows` (`<S-Delete>`), and `EasyDiffUndo` (`<Backspace>`).
* Supports merging between arbitrary diff windows using counts with `EasyDiffMergeDiffLeft` (`<Left>`) and `EasyDiffMergeDiffRight` (`<Right>`) for n-way diffs; Counts need not be specified for 2-way diffs.
* Supports navigation within a Diff (Start, End of a Diff) with the commands `EasyDiffJumpToDiffStart` (`<PageUp>`) and `EasyDiffJumpToDiffEnd` (`<PageDown>`).
* Supports navigation between Diffs (First, Last, Previous, Next) with the commands `EasyDiffJumpToFirstDiff` (`<Home>`), `EasyDiffJumpToLastDiff` (`<End>`), `EasyDiffJumpToPreviousDiff` (`<Up>`) and `EasyDiffJumpToNextDiff` (`<Down>`).
* Supports navigation between diff windows with the command `EasyDiffJumpToWindow` (`<Space>`).
* The commands are context aware; for example, regardless of which window contains the cursor, `EasyDiffMergeDiffRight` (`<Right>`) merges 2-way Diff from the left diff window to the right diff window. Any non-diff windows present are ignored. Similarly, `EasyDiffUndo` (`<Backspace>`) undoes the merges and deletes across window boundaries, independent of the current window. `EasyDiffUndo` (`<Backspace>`) atomically undoes simultaneous deletes in all diff windows performed with `EasyDiffDeleteDiffInAllWindows` (`<S-Delete>`).
* Handles all possible configurations of Diffs. When the cursor line represents multiple Diffs (previous filler, changed/added or EOF filler), the user is prompted to identify the target Diff for merge/delete operations.
* Automatically adapts to `diffopt+=linematch:{n}`, handling both grouped and split diffs transparently.
* The movement keys are enabled in visual mode as well; for example, with the default mappings one can select (visual) a Diff with `<PageUp>V<PageDown>`.

---
## Installation

1. Download `EasyDiff.vim`.
2. Place `EasyDiff.vim` into the plugin directory (e.g., `~/.vim/plugin/` or `~/.config/nvim/plugin/`), or source it directly in the Vim startup file (`.vimrc` or `init.vim`):

```vim
source /path/to/EasyDiff.vim
```
---

## Requirements

* Requires Vim 9.2 or Neovim 0.12.0 (the tested versions). EasyDiff might work in lower versions, but any issues found in lower versions are out of scope of this plugin.
* Requires at least two windows in diff mode. All diff windows must be in the same row of vertical splits.
* The diff windows may be set up directly using `vim -d`, `nvim -d`, or `vimdiff`, or by manually invoking `:diffthis`.
* Requires the default diff options `set cursorbind` and `set diffopt+=filler` to remain unmodified.
* When the `diffopt+=linematch:{n}` is specified, for correct alignment Vim and Neovim expect `{n}` to be greater than the product of the number of diff windows and the number of lines in the largest diff hunk.

---

## Commands and Default Key Bindings

| Command | Default Key | Action |
| :--- | :--- | :--- |
|`EasyDiffMergeDiffRight`| `<Right>` | 2-way diff: Merge current Diff from the **left** window to the **right** window; n-way diff: away from target window towards operating window *(accepts count; normal mode)* |
|`EasyDiffMergeDiffLeft`| `<Left>` | 2-way diff: Merge current Diff from the **right** window to the **left** window; n-way diff: towards target window away from operating window *(accepts count; normal mode)* |
|`EasyDiffDeleteDiffInCurrentWindow`| `<Delete>` | Delete the current Diff in the current window *(normal mode)* |
|`EasyDiffDeleteDiffInAllWindows`| `<S-Delete>` | Delete the current Diff in all diff windows *(normal mode)* |
|`EasyDiffUndo`| `<Backspace>` | Undo the last merge or delete *(normal mode)* |
|`EasyDiffJumpToDiffStart`| `<PageUp>` | Jump to the **start** of the current Diff *(normal and visual modes)* |
|`EasyDiffJumpToDiffEnd`| `<PageDown>` | Jump to the **end** of the current Diff *(normal and visual modes)* |
|`EasyDiffJumpToFirstDiff`| `<Home>` | Jump to the **first** Diff *(normal and visual modes)* |
|`EasyDiffJumpToLastDiff`| `<End>` | Jump to the **last** Diff *(normal and visual modes)* |
|`EasyDiffJumpToPreviousDiff`| `<Up>` | Jump to the **previous** Diff *(accepts count; normal and visual modes)* |
|`EasyDiffJumpToNextDiff`| `<Down>` | Jump to the **next** Diff *(accepts count; normal and visual modes)* |
|`EasyDiffJumpToWindow`| `<Space>` | Move cursor to a specific diff window *(accepts count; normal mode)* |
|`EasyDiffJumpToAlternateWindow`| `<S-Home>` | Move cursor to the alternate window *(normal mode)* |
|`EasyDiffToggleStayOnDiff`| `<S-End>` | Toggles the `g:easydiff_stay_on_diff` variable between `1` (default) and `0` *(normal mode)* |
|`EasyDiffHelp`| `<F1>` | Print help message *(normal mode)* |

> **Notes on the Commands and Bindings:**
> * The default key bindings may be disabled by setting the variable `let g:easydiff_enable_default_mappings = 0` and mapping custom alternatives to the commands directly; for example, this uses `<Leader>h` instead of the default `<F1>`: `noremap <Leader>h <Cmd>EasyDiffHelp<CR>`. It is also possible to retain the default mappings but only customize some of them in `s:easydiff_default_mappings` in EasyDiff.vim
> * The default key bindings are restricted to the diffed buffers. Preexisting key bindings are restored when diff is disabled.
> * Other key bindings are not affected. Particularly, `h`/`j`/`k`/`l`/`<C-f>`/`<C-b>`/`0`/`$`/`x` continue to provide the original functions of `<Left>`/`<Down>`/`<Up>`/`<Right>`,`<Space>`/`<PageDown>`/`<PageUp>`/`<Home>`/`<End>`/`<Delete>`.
> * A **Diff** is a contiguous region identified by Vim's diff engine. It may consist of one or more changed, added, or filler regions. For example, in 2-way diff, to delete lines in the right window that correspond to filler lines in the left window, invoke `EasyDiffMergeDiffRight` (`<Right>`). EasyDiff automatically executes `diffput` (or `diffget` from the other window) to produce the expected result.
> * In 2-way diffs, without count, `EasyDiffMergeDiffRight` (`<Right>`) / `EasyDiffMergeDiffLeft` (`<Left>`) merge towards right/left.
> * In n-way diff (n>2), `EasyDiffMergeDiffRight` (`<Right>`) and `EasyDiffMergeDiffLeft` (`<Left>`) accept a count to select the target and operating windows. A single digit count specifies the target window number and the operating window is the current window. For example, `3<Right>` merges the Diff from target window 3 to the current (operating) window. With two digits, the first digit is the target window and the second is the operating window; for example, `34<Right>` merges from target window 3 to operating window 4. With four digits the first two digits encode the target window, and the last two the operating window; for example `1002<Right>` merges from target window 10 to operating window 2. The direction determines whether the merge is away from (`<Right>`) or towards (`<Left>`) the target window.
> * `EasyDiffDeleteDiffInCurrentWindow` (`<Delete>`) deletes the Diff **only** in the current window. If the deleted Diff is adjacent to an existing Filler, Vim/Neovim combines the new and existing Fillers into a single, larger Diff. Then the new larger Diff may be merged with the other window using `<Left>` or `<Right>`.
> * `EasyDiffDeleteDiffInAllWindows` (`<S-Delete>`) first finds the full extent of the Diff in current window, including any Filler. Then it deletes this extent from **all** diff windows.
> * `EasyDiffUndo` (`<Backspace>`) undoes all the deletions in diff windows performed by a single `EasyDiffDeleteDiffInAllWindows` (`<S-Delete>`). To only undo one of those deletes, one may manually undo using 'u', but that will reset EasyDiff's undo tracking.
> * At start, the cursor is automatically placed on the first Diff in all diff windows.
> * `EasyDiffJumpToAlternateWindow` (`<S-Home>`) moves cursor to the corresponding line in the alternate diff window; once there, moves cursor as per variable `g:easydiff_stay_on_diff`. Vim/Neovim's native `<C-w>w` could instead be used to switch windows without readjusting the cursor position.
> * `EasyDiffJumpToWindow` (`<Space>`) accepts a count that specifies the diff window to move the cursor to. For example, `3<Space>` moves cursor to corresponding line in diff window 3; once there, it moves cursor as per the variable `g:easydiff_stay_on_diff`.
> * If the terminal does not support the shifted default key bindings `<S-Home>`, `<S-Delete>` and `<S-End>`, default alternatives `2<Home>`, `2<Delete>` and `2<End>` may be used.
> * For convenience (not essential to EasyDiff operations), these additional default mappings are provided: `3<End>` to toggle 'linematch' diffopt; `4<End>` to toggle 'set number'; `5<End>` to toggle 'report' between 0 and the saved value (or 2).

---

## Configuration Variables

### `g:easydiff_enable_default_mappings`
Enables or disables the default keybindings for the EasyDiff commands.
```vim
let g:easydiff_enable_default_mappings = 1
```
* **`(Default)`** Enables the default key bindings for the EasyDiff commands
```vim
let g:easydiff_enable_default_mappings = 0
```
* If set during initialization, disables the default key bindings for the EasyDiff commands. The user can provide their custom mappings for these commands.


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

* Vim and Neovim support up to 8 diff windows in a tab, though there is no limitation on the number of non-diff windows.
* EasyDiff tracks edits (merges/deletes) performed using `<Right>`, `<Left>`, `<Delete>` or `<S-Delete>`, allowing them to be repeatedly undone using `<Backspace>`. But manual edits that change changenr, will reset this edit tracking.
* Non-zero scrolloff is known to affect cursorbind in some cases in both Vim and Neovim. As cursorbind is essential for correct EasyDiff operations, it is recommended to keep `setlocal scrolloff=0` in diff windows.
* Vim/Neovim suppress messages from :delete when upto 'report' lines are deleted. But messages from undo or redo (and hence from merges) are not similarly suppressed. However, in n-way Diff especially, messages from merge/delete/undo serve as a useful feedback. It is therefore desirable to keep the setting `set report=0`, so that none of these messages are suppressed.
* Due to an upstream Vim/Neovim rendering quirk, an EOF filler may not be visible by default even though EasyDiff tracks it correctly; press `<C-e>` to reveal it.
* Vim (up to 9.2.914) and Neovim (up to 0.12.6) are affected by an upstream issue ([Vim #20950][1], [Neovim #41172][2]) where `:undo`, after a `:diffget` into an empty buffer, leaves an extra line behind. There is no workaround in EasyDiff for this issue.

[1]: https://github.com/vim/vim/issues/20950
[2]: https://github.com/neovim/neovim/issues/41172
