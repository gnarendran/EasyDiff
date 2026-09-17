# EasyDiff

**EasyDiff** provides a simplified keyboard interface for resolving diffs in Vim and Neovim. It abstracts Vim's mnemonic diff commands behind an intuitive cursor-key interface, simplifying navigation within and between diffs and making repetitive merge, delete, and undo operations faster.

---
## Requirements

* Requires Vim 9.2 or Neovim 0.12.0 (the tested versions). EasyDiff might work in lower versions, but any issues found in lower versions are out of scope of this plugin.
* Requires at least two windows in diff mode in the tab. All diff windows in a tab must be in the same row of vertical splits. Non-diff windows may also be present in vertical or horizontal splits.
* The diff windows may be set up directly using `vim -d`, `nvim -d`, or `vimdiff`, or by manually invoking `:diffthis`.
* Requires the default diff options `set cursorbind` and `set diffopt+=filler` to remain unmodified.
* When the `diffopt+=linematch:{n}` is specified, for correct alignment Vim and Neovim expect `{n}` to be greater than the product of the number of diff windows and the number of lines in the largest diff hunk.

---
## Terminology
* A Diff is a contiguous region identified by Vim's diff engine. It may consist of one or more of changed, added, or filler regions.
* 2-way diff refers to diff operations in a tab containing exactly two diff windows
* n-way diff refers to diff operations in a tab containing more than two diff windows
* **Operating window** refers to the diff window where the :diffget and :diffput commands are executed
* **Target window** refers to the diff window containing the other buffer whose number will be specified as argument to :diffget or :diffput.
* A Merge from **Target window** to **Operating window** copies text in the current Diff from the former to the latter. It is achieved by issuing :diffget in the **Operating window**. If the Diff includes a filler in the **Target window**, this Merge deletes the corresponding text in the **Operating window**.
* A Merge to **Target window** from **Operating window** copies text in the current Diff to the former from the latter. It is achieved by issuing :diffput in the **Operating window**. If the Diff includes a filler in the **Operating window**, this Merge deletes the the corresponding text in the **Target window**.
* The default key mappings for the commands are shown in brackets.
---
## Features

* Provides intuitive merge, delete (in current or in all diff windows) of Diffs, and globally tracked undo of the operations, using the commands `EasyDiffMergeDiffLeft` (`<Left>`), `EasyDiffMergeDiffRight` (`<Right>`), `EasyDiffDeleteDiffInCurrentWindow` (`<Delete>`), `EasyDiffDeleteDiffInAllWindows` (`<S-Delete>`), and `EasyDiffUndo` (`<Backspace>`).
* Supports merging between arbitrary diff windows using counts with `EasyDiffMergeDiffLeft` (`<Left>`) and `EasyDiffMergeDiffRight` (`<Right>`) for n-way diffs
* For 2-way diffs, counts need not be specified, and `EasyDiffMergeDiffRight` (`<Right>`) / `EasyDiffMergeDiffLeft` (`<Left>`) merge to right/left diff window, irrespective of which one of the two is the **Target** or **Operating window**.
* `EasyDiffUndo` (`<Backspace>`) undoes the merges and deletes across window boundaries, independent of the current window. It atomically undoes simultaneous deletes in all diff windows performed by a `EasyDiffDeleteDiffInAllWindows` (`<S-Delete>`).
* Supports navigation within a Diff (Start, End of a Diff) with the commands `EasyDiffJumpToDiffStart` (`<PageUp>`) and `EasyDiffJumpToDiffEnd` (`<PageDown>`).
* Supports navigation between Diffs (First, Last, Previous, Next) with the commands `EasyDiffJumpToFirstDiff` (`<Home>`), `EasyDiffJumpToLastDiff` (`<End>`), `EasyDiffJumpToPreviousDiff` (`<Up>`) and `EasyDiffJumpToNextDiff` (`<Down>`).
* Supports navigation between diff windows with the command `EasyDiffJumpToWindow` (`<Space>`) and `EasyDiffJumpToAlternateWindow` (`<S-Home>`).
* Handles all possible configurations of Diffs. When the cursor line represents multiple Diffs (previous filler, changed/added or EOF filler), the user is prompted to identify the Diff for merge/delete operations.
* Automatically adapts to `diffopt+=linematch:{n}`, handling both grouped and split diffs transparently.
* The movement keys are enabled in visual mode as well; for example, with the default mappings one can select (visual) a Diff with `<PageUp>V<PageDown>`.
* Non-diff windows may be present in vertical or horizontal splits, and they are ignored.

---
## Installation

1. Download `EasyDiff.vim`.
2. Place `EasyDiff.vim` into the plugin directory (e.g., `~/.vim/plugin/` or `~/.config/nvim/plugin/`), or source it directly in the Vim startup file (`.vimrc` or `init.vim`):

```vim
source /path/to/EasyDiff.vim
```
---

## Commands and Default Key Bindings

| Command | Default Key | Action |
| :--- | :--- | :--- |
| `EasyDiffMergeDiffRight` | `<Right>` | 2-way diff: Merge current Diff from the **left** diff window to the **right** diff window; n-way diff: from **Target window** to **Operating window** *(accepts count; normal mode)*. See [Merge commands and window selection](#merge-commands-and-window-selection) |
| `EasyDiffMergeDiffLeft` | `<Left>` | 2-way diff: Merge current Diff to the **left** diff window from the **right** diff window; n-way diff: to **Target window** from **Operating window** *(accepts count; normal mode)*. See [Merge commands and window selection](#merge-commands-and-window-selection) |
| `EasyDiffDeleteDiffInCurrentWindow` | `<Delete>` | Delete the current Diff only in the current window *(normal mode)*. See [Deleting Diff in current window](#deleting-diff-in-current-window) |
| `EasyDiffDeleteDiffInAllWindows` | `<S-Delete>` | Delete the current Diff in all diff windows *(normal mode)*. See [Deleting Diff in all windows](#deleting-diff-in-all-windows) |
| `EasyDiffUndo` | `<Backspace>` | Undo the last merge or delete *(normal mode)*. See [Undoing last merge or delete](#undoing-last-merge-or-delete) |
| `EasyDiffJumpToDiffStart` | `<PageUp>` | Jump to the **start** of the current Diff *(normal and visual modes)* |
| `EasyDiffJumpToDiffEnd` | `<PageDown>` | Jump to the **end** of the current Diff *(normal and visual modes)* |
| `EasyDiffJumpToFirstDiff` | `<Home>` | Jump to the **first** Diff *(normal and visual modes)* |
| `EasyDiffJumpToLastDiff` | `<End>` | Jump to the **last** Diff *(normal and visual modes)* |
| `EasyDiffJumpToPreviousDiff` | `<Up>` | Jump to the **previous** Diff *(accepts count; normal and visual modes)* |
| `EasyDiffJumpToNextDiff` | `<Down>` | Jump to the **next** Diff *(accepts count; normal and visual modes)* |
| `EasyDiffJumpToWindow` | `<Space>` | Move cursor to a specific diff window *(accepts count; normal mode)*. See [Jumping to a diff window](#jumping-to-a-diff-window) |
| `EasyDiffJumpToAlternateWindow` | `<S-Home>` | Move cursor to the alternate window *(normal mode)*. See [Jumping to alternate window](#jumping-to-alternate-window) |
| `EasyDiffToggleStayOnDiff` | `<S-End>` | Toggles the `g:easydiff_stay_on_diff` variable between `1` (default) and `0` *(normal mode)*. See [g:easydiff_stay_on_diff](#geasydiff_stay_on_diff) |
| `EasyDiffHelp` | `<F1>` | Print help message *(normal mode)* |

> **Notes on the Commands and Bindings:**

> * The default key bindings may be disabled by setting the variable `let g:easydiff_enable_default_mappings = 0` and mapping custom alternatives to the commands directly; for example, this uses `<Leader>h` instead of the default `<F1>`: `noremap <Leader>h <Cmd>EasyDiffHelp<CR>`. It is also possible to retain the default mappings but only customize some of them in `s:easydiff_default_mappings` in EasyDiff.vim
> * The default key bindings are restricted to the diffed buffers. Preexisting key bindings are restored when diff is disabled.
> * Other key bindings are not affected. Particularly, `h`/`j`/`k`/`l`/`<C-f>`/`<C-b>`/`0`/`$`/`x` continue to provide the original functions of `<Left>`/`<Down>`/`<Up>`/`<Right>`,`<Space>`/`<PageDown>`/`<PageUp>`/`<Home>`/`<End>`/`<Delete>`.
> * If the terminal does not support the shifted default key bindings `<S-Home>`, `<S-Delete>` and `<S-End>`, default alternatives `2<Home>`, `2<Delete>` and `2<End>` may be used.
> * For convenience (not essential to EasyDiff operations), these additional default mappings are provided: `3<End>` to toggle 'linematch' diffopt; `4<End>` to toggle 'set number'; `5<End>` to toggle 'report' between 0 and the saved value (or 2).
> * A **Diff** is a contiguous region identified by Vim's diff engine. It may consist of one or more changed, added, or filler regions. For example, in 2-way diff, to delete lines in the right window that correspond to filler lines in the left window, invoke `EasyDiffMergeDiffRight` (`<Right>`). EasyDiff automatically executes `diffput` (or `diffget` from the other window) to produce the expected result.
> * At start, the cursor is automatically placed on the first Diff in all diff windows.

### Merge commands and window selection
EasyDiff prefixes window numbers to every diff window's statusline. This number is used to address the **Target** and **Operating windows**, by a simple encoding in the count to the merge commands, as described below.

* In 2-way diff (2 diff windows), count need not be specified, and the command decides the direction of Merge, with the current diff window as the **Operating window**, and the other diff window as the **Target window**.
For example, if 5 is the current window, and 2 the other diff window:

| Key | Merge Direction | Command Execution |
| :--- | :--- | :--- |
| `<Right>` | from **Target**(2) to **Operating**(5) | :diffget is executed in 5 |
| `<Left>` | to **Target**(2) from **Operating**(5) | :diffput is executed in 5 |

* In n-way diff (3 or more diff windows) `EasyDiffMergeDiffRight` (`<Right>`) merges from the **Target window** to the **Operating window** (so :diffget is executed in the **Operating window**). `EasyDiffMergeDiffLeft` (`<Right>`) merges to the **Target window** from the **Operating window** (so :diffput is executed in the **Operating window**).

A count to the merge commands can specify the **Target** and **Operating window** numbers, as follows:

| Count | **Target window** | **Operating window** |
| :--- | :--- | :--- |
| None | 1 (by default) | Current window |
| One digit | The single digit | Current window |
| Two digits | First digit | Second digit |
| Three/Four digits | First one or two digits | Last two digits |

For example, with four diff windows with numbers 1, 3, 4, 10, and 4 being the current window:

| Key | Merge Direction | Command Execution |
| :--- | :--- | :--- |
| `<Right>` | from **Target**(1) to **Operating**(4) | :diffget is executed in 4 |
| `<Left>` | to **Target**(1) from **Operating**(4) | :diffput is executed in 4 |
| `3<Right>` | from **Target**(3) to **Operating**(4) | :diffget is executed in 4 |
| `3<Left>` | to **Target**(3) from **Operating**(4) | :diffput is executed in 4 |
| `34<Right>` | from **Target**(3) to **Operating**(4) | :diffget is executed in 4 |
| `34<Left>` | to **Target**(3) from **Operating**(4) | :diffput is executed in 4 |
| `13<Right>` | from **Target**(1) to **Operating**(3) | :diffget is executed in 3 |
| `13<Left>` | to **Target**(1) from **Operating**(3) | :diffput is executed in 3 |
| `310<Right>` | from **Target**(3) to **Operating**(10) | :diffget is executed in 10 |
| `310<Left>` | to **Target**(3) from **Operating**(10) | :diffput is executed in 10 |
| `410<Right>` | from **Target**(4) to **Operating**(10) | :diffget is executed in 10 |
| `410<Left>` | to **Target**(4) from **Operating**(10) | :diffput is executed in 10 |
| `1001<Right>` | from **Target**(10) to **Operating**(1) | :diffget is executed in 1 |
| `1001<Left>` | to **Target**(10) from **Operating**(1) | :diffput is executed in 1 |
| `1004<Right>` | from **Target**(10) to **Operating**(4) | :diffget is executed in 4 |
| `1004<Left>` | to **Target**(10) from **Operating**(4) | :diffput is executed in 4 |

When **Operating window** is different from the current window, the cursor movements in **Operating window** due to Merge and subsequently due to `g:easydiff_stay_on_diff`, will cause cursor to move correspondingly in the current window due to cursorbind.

### Deleting Diff in current window
`EasyDiffDeleteDiffInCurrentWindow` (`<Delete>`) deletes the Diff **only** in the current window. If the deleted Diff is adjacent to an existing Filler, Vim/Neovim combines the new and existing Fillers into a single, larger Diff. Then the new larger Diff may be further merged with another window using `EasyDiffMergeDiffLeft` (`<Left>`) or `EasyDiffMergeDiffRight` (`<Right>`).

### Deleting Diff in all windows
`EasyDiffDeleteDiffInAllWindows` (`<S-Delete>`) first finds the full extent of the Diff in current window, including any Filler. Then it deletes this extent from **all** diff windows.

### Undoing last merge or delete
`EasyDiffUndo` (`<Backspace>`) undoes merges and deletes across window boundaries. It atomically undoes all the deletions in diff windows performed by a single `EasyDiffDeleteDiffInAllWindows` (`<S-Delete>`). To only undo one of those deletes, one may manually undo using Vim/Neovim's native 'u', but that will reset EasyDiff's undo tracking.

### Jumping to a diff window
`EasyDiffJumpToWindow` (`<Space>`) accepts a count specifying the diff window to which the cursor should move. For example, `3<Space>` moves the cursor to the corresponding line in diff window 3; once there, it moves the cursor according to `g:easydiff_stay_on_diff`. Vim/Neovim's native `[winnr]<C-w>w` could instead be used to switch windows without readjusting the cursor position.

### Jumping to alternate window
`EasyDiffJumpToAlternateWindow` (`<S-Home>`) moves cursor to the corresponding line in the alternate diff window; once there, moves cursor as per variable `g:easydiff_stay_on_diff`. Vim/Neovim's native `<C-w>p` could instead be used to switch windows without readjusting the cursor position.

---

## Configuration Variables

### `g:easydiff_enable_default_mappings`
Enables or disables the default keybindings for the EasyDiff commands:
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
* **`(Default)`** After a Diff merge, delete, undo, or window switch, keep the cursor on a Diff: if it is not already on a Diff, move it to the next Diff; if there is no next Diff, move it to the last Diff.

```vim
let g:easydiff_stay_on_diff = 0
```
* After a Diff merge, delete, undo or window switch, no attempt is made to keep the cursor on a Diff.

---

## Limitations

* Vim and Neovim support up to 8 diff windows in a tab, though there is no limitation on the number of non-diff windows.
* EasyDiff tracks edits (merges/deletes) performed using `EasyDiffMergeDiffRight` (`<Right>`), `EasyDiffMergeDiffLeft` (`<Left>`), `EasyDiffDeleteDiffInCurrentWindow` (`<Delete>`) or `EasyDiffDeleteDiffInAllWindows` (`<S-Delete>`), allowing them to be repeatedly undone using `EasyDiffUndo` (`<Backspace>`). But manual edits that change changenr, will reset this edit tracking.
* Non-zero scrolloff is known to affect cursorbind in some cases in both Vim and Neovim. As cursorbind is essential for correct EasyDiff operations, EasyDiff executes `setlocal scrolloff=0` in all diff windows.
* Vim/Neovim suppress messages from :delete when upto 'report' lines are deleted. But messages from undo or redo (and hence from merges) are not similarly suppressed. However, in n-way Diff especially, messages from merge/delete/undo serve as a useful feedback. So, to ensure that none of these messages are suppressed, EasyDiff executes `set report=0` at start.
* Due to an upstream Vim/Neovim rendering quirk, an EOF filler may not be visible by default even though EasyDiff tracks it correctly; press `<C-e>` to reveal it.
* Vim (up to 9.2.914) and Neovim (up to 0.12.6) are affected by an upstream issue ([Vim #20950][1], [Neovim #41172][2]) where `:undo`, after a `:diffget` into an empty buffer, leaves an extra line behind. There is no workaround in EasyDiff for this issue.

[1]: https://github.com/vim/vim/issues/20950
[2]: https://github.com/neovim/neovim/issues/41172
