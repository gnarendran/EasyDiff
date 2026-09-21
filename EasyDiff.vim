"********************************************************************************
" Author  : Narendran Gopalakrishnan
" GitHub  : https://github.com/gnarendran/EasyDiff
" Usage   : source this Vim script anywhere in Vim/Neovim startup scripts, say
"           in vimrc ($XDG_CONFIG_HOME/vim/vimrc maybe) or init.nvim (say
"           $XDG_CONFIG_HOME/nvim/init.vim), or drop it in the plugin directory.
"********************************************************************************
" Introduction {{{1
"  EasyDiff provides a simplified keyboard interface for resolving diffs in Vim
"  and Neovim. It abstracts Vim's mnemonic diff commands behind an intuitive
"  cursor-key interface, simplifying navigation within and between diffs and
"  making repetitive merge, delete, and undo operations faster.
"
" Requirements {{{1
" ‾‾‾‾‾‾‾‾‾‾‾‾
" - Requires Vim 9.2 or Neovim 0.12.0 (the tested versions). EasyDiff might work
"   in lower versions, but any issues found in lower versions are out of scope
"   of this plugin.
" - Requires at least two windows in diff mode in the tab. All diff windows in a
"   tab must be in the same row of vertical splits. Non-diff windows may also be
"   present in vertical or horizontal splits.
" - The diff windows may be set up directly using vim -d, nvim -d, or vimdiff,
"   or by manually invoking :diffthis.
" - Requires the default diff options `set cursorbind` and `set diffopt+=filler`
"   to remain unmodified.
" - When the `diffopt+=linematch:{n}` is specified, for correct alignment Vim
"   and Neovim expect `{n}` to be greater than the product of the number of diff
"   windows and the number of lines in the largest diff hunk.
"
" Terminology {{{1
" ‾‾‾‾‾‾‾‾‾‾‾
" - A Diff is a contiguous region identified by Vim's diff engine. It may
"   consist of one or more of changed, added, or filler regions.
" - 2-way diff refers to diff operations in a tab containing exactly two diff
"   windows
" - n-way diff refers to diff operations in a tab containing more than two diff
"   windows
" - **Operating window** refers to the diff window where the :diffget and
"   :diffput commands are executed.
" - **Target window** refers to the diff window containing the other buffer
"   whose number will be specified as argument to :diffget or :diffput.
" - A Merge from **Target window** to **Operating window** copies text in the
"   current Diff from the former to the latter. It is achieved by issuing
"   :diffget in the **Operating window**. If the Diff includes a filler in the
"   **Target window**, Merge deletes the corresponding text in the **Operating
"   window**.
" - A Merge to **Target window** from **Operating window** copies text in the
"   current Diff to the former from the latter. It is achieved by issuing
"   :diffput in the **Operating window**. If the Diff includes a filler in the
"   **Operating window**, Merge deletes the the corresponding text in the
"   **Target window**
" - The default key mappings for the commands are shown in brackets.
"
" Commands and Default Key Bindings {{{1
" ‾‾‾‾‾‾‾‾ ‾‾‾ ‾‾‾‾‾‾‾ ‾‾‾ ‾‾‾‾‾‾‾‾
"	Command					Default Key	Action
"	‾‾‾‾‾‾‾					‾‾‾‾‾‾‾ ‾‾‾	‾‾‾‾‾‾
"	`EasyDiffMergeDiffRight`		`<Right>`	2-way diff: Merge from **left** diff window to **right** diff window; n-way diff: from **Target window** to **Operating window** *(accepts count; normal mode)*. See 'Merge commands and window selection'
"	`EasyDiffMergeDiffLeft`			`<Left>`	2-way diff: Merge to **left** diff window from **right** diff window; n-way diff: to **Target window** from **Operating window** *(accepts count; normal mode)*. See 'Merge commands and window selection'
"	`EasyDiffDeleteDiffInCurrentWindow`	`<Delete>`	Delete the current Diff only in the current window *(normal mode)*. See 'Deleting Diff in current window'
"	`EasyDiffDeleteDiffInAllWindows`	`<S-Delete>`	Delete the current Diff in all diff windows *(normal mode)*. See 'Deleting Diff in all windows'
"	`EasyDiffUndo`				`<Backspace>`	Undo the last merge or delete *(normal mode)*. See 'Undoing last merge or delete'
"	`EasyDiffJumpToDiffStart`		`<PageUp>`	Jump to the **start** of the current Diff *(normal and visual modes)*
"	`EasyDiffJumpToDiffEnd`			`<PageDown>`	Jump to the **end** of the current Diff *(normal and visual modes)*
"	`EasyDiffJumpToFirstDiff`		`<Home>`	Jump to the **first** Diff *(normal and visual modes)*
"	`EasyDiffJumpToLastDiff`		`<End>`		Jump to the **last** Diff *(normal and visual modes)*
"	`EasyDiffJumpToPreviousDiff`		`<Up>`		Jump to the **previous** Diff *(accepts count; normal and visual modes)*
"	`EasyDiffJumpToNextDiff`		`<Down>`	Jump to the **next** Diff *(accepts count; normal and visual modes)*
"	`EasyDiffJumpToWindow`			`<Space>`	Move cursor to a specific diff window *(accepts count; normal mode)*. See 'Jumping to a diff window'
"	`EasyDiffJumpToAlternateWindow`		`<S-Home>`	Move cursor to the alternate window *(normal mode)*. See 'Jumping to alternate window'
"	`EasyDiffToggleStayOnDiff`		`<S-End>`	Toggles the `g:easydiff_stay_on_diff` variable between `1` (default) and `0` *(normal mode)*. See 'g:easydiff_stay_on_diff'
"	`EasyDiffHelp`				`<F1>`		Print help message *(normal mode)*
"
" Notes on the Commands and Bindings {{{2
" ‾‾‾‾‾ ‾‾ ‾‾‾ ‾‾‾‾‾‾‾‾ ‾‾‾ ‾‾‾‾‾‾‾‾
" - The default key bindings may be disabled by setting the variable
"   `let g:easydiff_enable_default_mappings = 0` and mapping custom alternatives
"   to the commands directly; for example, this maps `<Leader>h` instead of the
"   default `<F1>`: `noremap <Leader>h <Cmd>EasyDiffHelp<CR>`. It is also
"   possible to retain the default mappings but only customize some of them in
"   `s:easydiff_default_mappings` in EasyDiff.vim
" - The default key bindings are restricted to the two diff'ed buffers.
"   Preexisting key bindings are restored when diff is disabled.
" - Other key bindings are not affected. Particularly,
"   `h`/`j`/`k`/`l`/`<C-f>`/`<C-b>`/`0`/`$`/`x` continue to provide the original
"   functions of `<Left>`/`<Down>`/`<Up>`/`<Right>`,`<Space>`/`<PageDown>`/`<PageUp>`/`<Home>`/`<End>`/`<Delete>`.
" - If the terminal does not support the shifted default key bindings
"   `<S-Home>`, `<S-Delete>` and `<S-End>`, default alternatives `2<Home>`,
"   `2<Delete>` and `2<End>` may be used.
" - For convenience (not essential to EasyDiff operations), these additional
"   default mappings are provided: `3<End>` to toggle 'linematch' diffopt;
"   `4<End>` to toggle 'set number'; `5<End>` to toggle 'report' between 0 and
"   the saved value (or 2).
" - At start, the cursor is automatically placed on the first Diff in all diff
"   windows.
"
" Merge commands and window selection {{{2
" ‾‾‾‾‾ ‾‾‾‾‾‾‾‾ ‾‾‾ ‾‾‾‾‾‾ ‾‾‾‾‾‾‾‾‾
" - EasyDiff prefixes window numbers to every diff window's statusline. This
"   number is used to address the **Target** and **Operating windows**, by a
"   simple encoding in the count to the merge commands, as described below.
" - In 2-way diff, count need not be specified, and the command decides the
"   direction of Merge, with the current diff window as the **Operating
"   window**, and the other diff window as the **Target window**.
"
"   For example, if 5 is the current window, and 2 the other diff window:
"
"	Key		Merge Direction					Command Execution
"	‾‾‾		‾‾‾‾‾ ‾‾‾‾‾‾‾‾‾					‾‾‾‾‾‾‾ ‾‾‾‾‾‾‾‾‾
"	<Right>		from **Target**(2) to **Operating**(5)		:diffget is executed in 5
"	<Left>		to **Target**(2) from **Operating**(5)		:diffput is executed in 5
"
" - In n-way diff (3 or more diff windows) `EasyDiffMergeDiffRight` (`<Right>`)
"   merges from the **Target window** to the **Operating window** (so :diffget
"   is executed in the **Operating window**). `EasyDiffMergeDiffLeft`
"   (`<Right>`) merges to the **Target window** from the **Operating window**
"   (so :diffput is executed in the **Operating window**).
"
"   A count to the merge commands can specify the **Target** and **Operating
"   window** numbers, as follows:
"
"	Count			**Target window**		**Operating window**
"	‾‾‾‾‾			‾‾‾‾‾‾‾‾ ‾‾‾‾‾‾‾‾		‾‾‾‾‾‾‾‾‾‾‾ ‾‾‾‾‾‾‾‾
"	None			1 (by default)			Current window
"	One digit		The single digit		Current window
"	Two digits		First digit			Second digit
"	Three/Four digits	First one or two digits		Last two digits

"   For example, with four diff windows with numbers 1, 3, 4, 10, and 4 being
"   the current window:
"
"	Key		Merge Direction					Command Execution
"	‾‾‾		‾‾‾‾‾ ‾‾‾‾‾‾‾‾‾					‾‾‾‾‾‾‾ ‾‾‾‾‾‾‾‾‾
"	`<Right>`	from **Target**(1) to **Operating**(4)		:diffget is executed in 4
"	`<Left>`	to **Target**(1) from **Operating**(4)		:diffput is executed in 4
"	`3<Right>`	from **Target**(3) to **Operating**(4)		:diffget is executed in 4
"	`3<Left>`	to **Target**(3) from **Operating**(4)		:diffput is executed in 4
"	`34<Right>`	from **Target**(3) to **Operating**(4)		:diffget is executed in 4
"	`34<Left>`	to **Target**(3) from **Operating**(4)		:diffput is executed in 4
"	`13<Right>`	from **Target**(1) to **Operating**(3)		:diffget is executed in 3
"	`13<Left>`	to **Target**(1) from **Operating**(3)		:diffput is executed in 3
"	`310<Right>`	from **Target**(3) to **Operating**(10)		:diffget is executed in 10
"	`310<Left>`	to **Target**(3) from **Operating**(10)		:diffput is executed in 10
"	`410<Right>`	from **Target**(4) to **Operating**(10)		:diffget is executed in 10
"	`410<Left>`	to **Target**(4) from **Operating**(10)		:diffput is executed in 10
"	`1001<Right>`	from **Target**(10) to **Operating**(1)		:diffget is executed in 1
"	`1001<Left>`	to **Target**(10) from **Operating**(1)		:diffput is executed in 1
"	`1004<Right>`	from **Target**(10) to **Operating**(4)		:diffget is executed in 4
"	`1004<Left>`	to **Target**(10) from **Operating**(4)		:diffput is executed in 4

" - When **Operating window** is different from the current window, the cursor
"   movements in **Operating window** due to Merge and subsequently due to
"   `g:easydiff_stay_on_diff`, will cause cursor to move correspondingly in the
"   current window due to cursorbind.
"
" Deleting Diff in current window {{{2
" ‾‾‾‾‾‾‾‾ ‾‾‾‾ ‾‾ ‾‾‾‾‾‾‾ ‾‾‾‾‾‾
" - `EasyDiffDeleteDiffInCurrentWindow` (`<Delete>`) deletes the Diff **only**
"   in the current window. If the deleted Diff is adjacent to an existing
"   Filler, Vim/Neovim combines the new and existing Fillers into a single,
"   larger Diff. Then the new larger Diff may be further merged with another
"   window using `EasyDiffMergeDiffLeft` (`<Left>`) or `EasyDiffMergeDiffRight`
"   (`<Right>`).

" Deleting Diff in all windows {{{2
" ‾‾‾‾‾‾‾‾ ‾‾‾‾ ‾‾ ‾‾‾ ‾‾‾‾‾‾‾
" - `EasyDiffDeleteDiffInAllWindows` (`<S-Delete>`) first finds the full extent
"   of the Diff in current window, including any Filler. Then it deletes this
"   extent from **all** diff windows.

" Undoing last merge or delete {{{2
" ‾‾‾‾‾‾‾ ‾‾‾‾ ‾‾‾‾‾ ‾‾ ‾‾‾‾‾‾
" - `EasyDiffUndo` (`<Backspace>`) undoes merges and deletes across window
"   boundaries. It atomically undoes all the deletions in diff windows performed
"   by a single `EasyDiffDeleteDiffInAllWindows` (`<S-Delete>`). To only undo
"   one of those deletes, one may manually undo using Vim/Neovim's native 'u',
"   but that will reset EasyDiff's undo tracking.

" Jumping to a diff window {{{2
" ‾‾‾‾‾‾‾ ‾‾ ‾ ‾‾‾‾ ‾‾‾‾‾‾
" - `EasyDiffJumpToWindow` (`<Space>`) accepts a count specifying the diff
"   window to which the cursor should move. For example, `3<Space>` moves the
"   cursor to the corresponding line in diff window 3; once there, it moves the
"   cursor according to `g:easydiff_stay_on_diff`. Vim/Neovim's native
"   `[winnr]<C-w>w` could instead be used to switch windows without readjusting
"   the cursor position.

" Jumping to alternate window {{{2
" ‾‾‾‾‾‾‾ ‾‾ ‾‾‾‾‾‾‾‾‾ ‾‾‾‾‾‾
" - `EasyDiffJumpToAlternateWindow` (`<S-Home>`) moves cursor to the
"   corresponding line in the alternate diff window; once there, moves cursor as
"   per variable `g:easydiff_stay_on_diff`. Vim/Neovim's native `<C-w>p` could
"   instead be used to switch windows without readjusting the cursor position.

" Configuration Variables {{{1
" ‾‾‾‾‾‾‾‾‾‾‾‾‾ ‾‾‾‾‾‾‾‾‾
" `g:easydiff_enable_default_mappings`
" - Enables or disables the default keybindings for the EasyDiff commands:
"  let g:easydiff_enable_default_mappings = 1
"  - (Default) Enables the default key bindings for the EasyDiff commands
"  let g:easydiff_enable_default_mappings = 0
"  - If set during initialization, disables the default key bindings for the
"    EasyDiff commands. The user can provide their custom mappings for these
"    commands.
"
" `g:easydiff_stay_on_diff`
" - Controls cursor positioning after an edit or window switch:
"  let g:easydiff_stay_on_diff = 1
"  - (Default) After a Diff Merge, Delete, Undo, or window switch, keep the
"    cursor on a Diff: if it is not already on a Diff, move it to the next Diff;
"    if there is no next Diff, move it to the last Diff.
"  let g:easydiff_stay_on_diff = 0
"  - After a Diff Merge, Delete, Undo or window switch, no attempt is made to
"    keep the cursor on a Diff.
"
" Limitations {{{1
" ‾‾‾‾‾‾‾‾‾‾‾
" - Vim and Neovim support up to 8 diff windows in a tab, though there is no
"   limitation on the number of non-diff windows.
" - EasyDiff tracks edits (merges/deletes) performed using
"   `EasyDiffMergeDiffRight` (`<Right>`), `EasyDiffMergeDiffLeft` (`<Left>`),
"   `EasyDiffDeleteDiffInCurrentWindow` (`<Delete>`) or
"   `EasyDiffDeleteDiffInAllWindows` (`<S-Delete>`), allowing them to be
"   repeatedly undone using `EasyDiffUndo` (`<Backspace>`). But manual edits
"   that change changenr, will reset this edit tracking.
" - Non-zero scrolloff is known to affect cursorbind in some cases in both Vim
"   and Neovim. As cursorbind is essential for correct EasyDiff operations,
"   EasyDiff executes `setlocal scrolloff=0` in all diff windows.
" - Vim/Neovim suppress messages from :delete when upto 'report' lines are
"   deleted. But messages from undo or redo (and hence from merges) are not
"   similarly suppressed. However, in n-way Diff especially, messages from
"   merge/delete/undo serve as a useful feedback. So, to ensure that none of
"   these messages are suppressed, EasyDiff executes `set report=0` at start.
" - Due to an upstream Vim/Neovim rendering quirk, an EOF filler may not be
"   visible by default even though EasyDiff tracks it correctly; press `<C-e>`
"   to reveal it.
" - Vim (up to 9.2.914) and Neovim (up to 0.12.6) are affected by an upstream
"   issue ([Vim #20950][1], [Neovim #41172][2]) where `:undo`, after a
"   `:diffget` into an empty buffer, leaves an extra line behind. There is no
"   workaround in EasyDiff for this issue.
"
" Implementation Notes {{{1
" ‾‾‾‾‾‾‾‾‾‾‾‾‾‾ ‾‾‾‾‾
" - Default Mapping Keys have been chosen to avoid confusion with normal editing
"   commands, especially accidental 'u' instead of the tracked undo of Diff
"   Merges and Deletes.
" - <Delete>, <Home> and <End> are overloaded with preceding count, as some
"   terminals can't distinguish between <Delete> and <S-Delete> etc..
" - curline refers to the line containing the cursor
" - diff mode enables 'cursorbind' which ensures that as curline in one window
"   changes, the curline in the other window also changes correspondingly. It
"   also binds column and curswant similarly. This binding between the cursor
"   keeps track of the Diff presentation. See :help 'cursorbind'.
"   Workaround1: For Vim and Neovim issue: win_execute 'undo' does not trigger
"   cursorbind (cursor in the local window doesn't move), while win_execute of
"   the equivalent normal command 'normal! u' triggers cursorbind correctly.
"   Similarly, :delete and :call setpos() don't wake up cursorbind. But a
"   subsequent 'normal! kj' (or even 'echo ""') triggers cursorbind and forces
"   cursor synchronization. This plugin uses normal commands j and k are used
"   for these cursor movements as they, unlike gg or G, preserve col/curswant
"   and don't affect the jumplist also.
" - In Vim/Neovim diff mode, curline is classified into four main categories
"   based on how it compares with its corresponding line in the other window:
"   changed:   Differs by at least one character. We refer to a set of
"              consecutive changed lines as 'Changed'
"   added:     Exists in this window, but not in another. We refer to a set of
"              consecutive Added lines as 'Added'.
"   - curline is in Added or Changed, if and only if diff_hlID(curline, 1) != 0
"   unchanged: Identical in all windows. curline is unchanged if and only if
"              diff_hlID(curline, 1) == 0
"   deleted:   Does not exist in this window, but exists in another.
"   - A set of consecutive deleted lines in one window is called a Filler.
"     Filler is a presentation artifact, and curline can never belong to a
"     Filler. A Filler is identified relative to an existing curline: A Filler
"     precedes curline if and only if diff_filler(curline) > 0 (equal to the
"     number of lines in the Filler).
"     As a special case, if curline is the last line and a Filler (called 'EOF
"     Filler') follows it, then that 'EOF Filler' is considered to precede a
"     *virtual line* curline+1. This 'EOF Filler' is identified by
"     diff_filler(curline+1) > 0 (equal to the number of lines in the 'EOF
"     Filler'). NOTE1: In Vim/Neovim help there were some hints, but no explicit
"     mention, of this special case.
"     See:
"     https://github.com/vim/vim/issues/20990
"     https://github.com/neovim/neovim/issues/41256
"
"   - If 'linematch:{n}' is present in diffopt, Vim/Neovim consider each
"     Changed, Added or Filler set, as a separate Diff, whether or not the sets
"     are adjacent to each other.
"   - Without the 'linematch:{n}' diffopt, Vim/Neovim combine consecutive
"     Changed and Added sets into a single Diff. If a Filler follows a Changed
"     (or Added) set, the Filler is combined with that Changed (or Added) set as
"     a single Diff. Further, Filler can only be at the end of any Diff.
"   - The 'Current Diff' is the Diff containing curline. In the case of a Filler
"     that is a separate Diff by itself (ie. the Filler is not combined with
"     another set into a single Diff), the Filler will be the 'Current Diff' if
"     and only if curline immediately follows the Filler.
" - Merge Operations:
"   - The command :diffput merges 'Current Diff' from the current (operating)
"     window *to* the target window
"   - The command :diffget merges 'Current Diff' *from* the target window to the
"     current (operating) window.
"
"   As defined, there cannot be a curline following the 'EOF Filler'. So if the
"   'EOF Filler' is a standalone Diff (linematch is enabled or the preceding
"   line is Unchanged), there is no line that represents the 'EOF Filler' and
"   the *only* way to operate on is by performing the opposite operation on the
"   corresponding Added set in the other window.
"
"   Further under 'linematch:{n}' in diffopt, which treats each of Added,
"   Changed, Filler sets as a separate Diff, if curline is the first line of a
"   Added(or Changed) set, but if the curline also follows a Filler, there is an
"   ambiguity about the set (whether Filler or Added(or Changed)) to which a
"   given operation applies. So the user is prompted to choose, and if the user
"   chooses the Filler, then again the switched operation described in the
"   previous paragraph is performed.
"
" - Vim/Neovim diff presentation invariants:
"   - The diff algorithm (myers, minimal, patience, histogram) affects hunk
"     computation only, not rendering rules.
"   - Filler lines exist only to equalize the displayed height of corresponding
"     regions across diff windows.
"   - Each filler line corresponds one-to-one with an Added line in another diff
"     window.
"   - Filler lines are contiguous and are never interleaved with real lines.
"   - Corresponding Unchanged lines remain vertically aligned across all diff
"     windows.
"   - Without linematch, all Filler corresponding to a run of Added lines
"     appears as one contiguous block at the end of the enclosing Diff.
"   - With linematch, a Diff is internally partitioned into independently
"     aligned sub-Diffs. For practical purposes (rendering and diff commands),
"     each sub-Diff behaves like a normal Diff: Added runs correspond to
"     contiguous Filler blocks on the opposite side, and Changed runs correspond
"     only to Changed runs.
"
" - <S-Delete> deletes the Diff in current window and also deletes the same
"   extent in all the other windows. When <Backspace> undoes <S-Delete>, it
"   undoes all these deletes atomically, treating all the windows as a group.
" - Ref :help undo-blocks : Consecutive edits performed in the *another* window
"   via win_execute() and similarly via :diffput, remain in a single undo block
"   with the same changenr(). To force every Diff Merge into its own undo block
"   (and thus a different changenr()) after a Merge to the other window, the
"   suggested solution is 'let &g:undolevels = &g:undolevels'.
"   Workaround2: Though a global option, the solution works only if the
"   assignment is also done in the other window!
"
"-  without noautocmd 'wincmd w' causes WinEnter and various other events. For
"   example it triggers matchparen.vim s:Highlight_Matching_Pair() that has
"   timed redraws, and resulted in echomsg being lost etc. Similarly, though
"   win_execute() itself doesn't trigger autocmds, the commands executed by it
"   might, so they are executed with noautocmd.
"
" - s:JumpToDiffStart() uses j[c or k]c. But s:JumpToDiffEnd() is implemented
"   with diff_hlID(), which is O(hunk size) - haven't found a better method
"   (considered ]c, diff folds etc.).
"
" - If the file is larger than a screenful, an 'EOF Filler' isn't rendered.
"   Workaround3: There is no clean workaround yet for this other than using
"   <C-e>.
"
" - Ref: :help diffupdate : Any edit (including those by diffget/diffput) that
"   could change a line should be followed by a diffupdate to update the diff
"   state.
" - Ref: :help mark and help :keepjumps : used to hide intermediate cursor jumps
"   (that aren't meaningful to the user).
"   Workaround10: ":mark '" does not store column, only "normal! m'" does. Also
"   there is no way do delete a ' mark (see :help :delmark). So it is not
"   possible to first create a mark and upon some failure clear the mark.
"   Instead, we have to clear the mark for the previous position afer success.
" - Commands such as [c and ]c jump to the column 1 of the line
"   ignoring the previous column and curswant. Workaround11: After these
"   commands we have to restore the column and curswant manually.
" - Workaround4: For Vim/Neovim-0.11.6 bug (likely fixed in Neovim-0.12.0):
"   After a Merge/Undo and a further diffupdate, in some cases subsequent
"   diff_hlID computes wrong, until rendered. Computing it once before that in
"   the other window makes the value come out right.
" - NOTE6: Neovim-0.11.6 bug fixed in Neovim-0.12.0: If a Diff precedes 'EOF
"   Filler', a :diffget on the Diff also does a :diffget on the Filler.
"   Workaround5: Specify also the range of lines to :diffget
" - Workaround6: For bug in Vim 9.2.390 and Neovim 0.12.4: When linematch is
"   enabled, delete or undo followed by diffupdate doesn't restore (contrary to
"   what ':h diffupdate' says) the correspondence between the cursors in the two
"   windows. For example, consider C1-F-C3 in W1, and C2-A-C4 in W2. When C1 is
"   deleted, it results in F'-C3 in W1 and A'-C4 in W2. But while the cursor
"   moves to C3 in W1 (correctly), it continues to stay in C2 that is part of A'
"   in W2, inspite of diffupdate. But this is still legal as C3 represents F'
"   and thus corresponds to C2. The workaround is to toggle the cursor using kj
"   or jk, which brings the cursor to C4 in W2. Now consider this: An undo is
"   performed, causing C1 to reappear in the old configuration, and the cursor
"   in W1 back in C1. But now in spite of diffupdate, cursor stays in C4 in W2,
"   which is incorrect as there is now no correspondence between C1 and C4.
"   See:
"   https://github.com/vim/vim/issues/20982
"   https://github.com/neovim/neovim/issues/41250
" - Workaround7: In both Vim and Neovim, a non-zero scrolloff (say scrolloff=999
"   to center the cursor), makes cursorbind go wrong, mostly when a window
"   cannot scroll more. Couldn't find a workaround other than forcing
"   'setlocal scrolloff=0'
" - NOTE2: Messages from :diffget/:diffput like 'W10: Warning: Changing a
"   readonly file' aren't exceptions. But when invoked from within functions,
"   they are printed with Vim's function context which we don't need. So silent
"   is used to suppress the original output, and then s:Message() redisplays
"   them without Vim's function context.
" - NOTE3: There is a bug in Vim 9.2.390 and Neovim 0.12.4, fixed in later
"   versions of Vim/Neovim, involving :diffget (normal do) into an empty buffer.
"   See:
"   [1]: https://github.com/vim/vim/issues/20950
"   [2]: https://github.com/neovim/neovim/issues/41172
" - Both in Vim and Neovim, :delete reports one fewer line when deleting the
"   entire buffer, but :undo on an empty buffer reports correctly. See:
"   https://github.com/vim/vim/issues/21049
"   https://github.com/neovim/neovim/issues/41306
"   Workaround8: When :delete results in an empty buffer, correct its message in
"   line with :undo, while honoring 'report' (see :h 'report') as well.
" - :diffget and :diffput do not report back the changes made ('1 line less', '2
"   more lines', '3 changes' etc.), unlike other ex commands. Workaround9:
"   Emulate the messages that ought to have been generated by these commands.
" - NOTE4: For Workaround1 and Workaround6, kj or jk could be used to vertically
"   toggle the cursor. But when no diff is present and all lines are inside a
"   single fold, 'silent normal! kj' etc. fail withs a beep. To avoid the beep,
"   one may use silent! instead, but that will let the rest of the normal
"   command to also be executed which is not desirable in some cases. Instead
"   using <count>G that is free of this issue.
" - NOTE5: edits and undo's by commands other than the standard diff commands
"   (:diffget, :diffput, [c, ]c etc.), can leave the diff display temporarily
"   stale and out of sync. So a subsequent message might disappear when an auto
"   diffupdate/redraw syncs the diff. To workaround, proactively diffupdate
"   after edits/undo's, before a echo/echomsg.
" - The interface is wrapped by set lazyredraw to prevent screen flickers etc.
" - NOTE7: cursorbind could move cursor in the current window due to undo or
"   merge to other windows. It is debatable whether cursor should be restored in
"   the current window after those operations, considering the current window to
"   be the source of truth of the cursor positon. On the other hand it may be
"   thought that the cursor should track the changes to the Diffs, and not be
"   tied to the previous position in the current window. This implementation
"   does not restore cursor.

" Variables {{{1
let s:thisfile = expand('<sfile>:p')
let s:saved_linematch=''
let s:editor_version = ''
" easydiff_undo_stack (tab-local): Stack of tracked Diff Merges and Deletes.
" Each entry is {'winid': ..., 'changenr': ..., 'grouped': ...}.
" 'grouped' means "undo this entry and continue the undo loop to the
" next (earlier) entry, rather than stopping." For a <S-Delete>, the
" later-pushed entry is grouped:true; the earlier-pushed one is
" grouped:false, marking where the compound undo should stop.
" Undo() only succeeds if the buffer is still at the changenr.
let t:easydiff_undo_stack = []
" The following are set by s:DiffStateValid():
" used by MergeDiff() to detect 2-way diff
let t:easydiff_windows = 0
" used instead of winnr(), by various functions
let t:easydiff_curwinnr = 0
" used for '#' (or any other valid diff window), by MergeDiff() and StayOnDiff()
let t:easydiff_otherwinnr = 0

" ShowHelp {{{1
" Presents the help information from the beginning of this file
function! s:ShowHelp() abort
	let lines = readfile(s:thisfile)

	let start = -1
	let end = len(lines)

	" Find the markers.
	for i in range(len(lines))
		if start < 0 && lines[i] =~# '\v^" Introduction \{\{\{1'
			let start = i+1
		elseif start >= 0 && lines[i] =~# '\v^" Implementation Notes \{\{\{1'
			let end = i
			break
		endif
	endfor

	if start < 0
		call s:Message('WED011: "Introduction:" help section not found.')
		return
	endif

	let title = 'EasyDiff on ' . s:editor_version
	" Initialize with title and a decorator
	let help = [title, substitute(title, '.', '‾', 'g')]
	" Add help text after removing leading comment prefix, and trailing {{{ fold marker
	let help += map(lines[start : end - 1], {_, v -> substitute(v, '^\s*"\s\?\|\s*{{{\d\+.*$', '', 'g')})
	echo join(help, "\n")
endfunction

" FileSize {{{1
" Returns the actual size of file in window. This takes into account that
" line('$') is 1 even in an empty file.
function! s:FileSize() abort
	let size = line('$')
	if size == 1 && empty(getline(1))
		let size = 0
	endif
	return size
endfunction

" WinEval {{{1
" Helper for various functions
" Evaluate expression in a target window and return the result. Used to query
" the state of the window.
" winid: id of the target window
" expr : expression to be evaluated in winid's context. This expression should
"        NOT in turn call WinEval, as that would corrupt the global
"        g:EasyDiff_tmp_out used to return the value.
function! s:WinEval(winid, expr) abort
	call win_execute(a:winid, 'noautocmd let g:EasyDiff_tmp_out = ' . a:expr)
	let result = g:EasyDiff_tmp_out
	unlet g:EasyDiff_tmp_out
	return result
endfunction

" ToggleCursor {{{1
" Helper for various functions.
" See 'Implementation Notes' Workaround1. Toggle cursor vertically to make
" cursorbind take effect
function! s:ToggleCursor() abort
	let pos = getcurpos()
	" Toggling up and then down cannot ensure line correspondence in these
	" cases: In n-way diff when linematch is enabled, consider A-F-U with
	" cursor at U. Then cursor is trapped in other window by A corresponding
	" to F, rather than reaching U corresponding to U. So toggle down-up
	" with normal jk - but this is possible only when curline is not the
	" last line:
	if pos[1] < line('$')
		noautocmd normal! jk
		return
	endif
	" For the last line:
	" - find the window with the largest last screen position (not the
	"   largest size!):
	let curwinnr = winnr()
	let largest_winid = 0
	let largest_winline = 0
	for winnr in range(1, winnr('$'))
		if winnr == curwinnr || !getwinvar(winnr, '&diff')
			continue
		endif
		let winid = win_getid(winnr)
		let lastwinline = screenpos(winid, line('$', winid), 1).row
		if largest_winline < lastwinline
			let largest_winid = winid
			let largest_winline = lastwinline
		endif
	endfor
	" - move to its last line, tickle cursorbind awake with a
	"   [curwinnr]<C-w>w (within win_execute, <C-w><C-w> doesn't work
	"   instead), and thus ensure the correspondence.
	if largest_winline > 0
		call win_execute(largest_winid, 'noautocmd silent keepjumps normal! G' . curwinnr . "\<C-w>w")
		" If current window's winline had been ever larger, its line
		" would've been moved up by cursorbind. Its column would've been
		" moved even otherwise. So restore them. Note that this doesn't
		" affect line correspondences established above.
		call s:CommitCursorMove(pos, pos[1], v:false)
	endif
endfunction

" Workaround2_changenr {{{1
" See 'Implementation Notes' Workaround2
" changed_winid: id of the window that was edited
" Returns its changenr()
function! s:Workaround2_changenr(changed_winid) abort
	call win_execute(a:changed_winid, 'noautocmd let &g:undolevels = &g:undolevels|noautocmd let g:EasyDiff_tmp_out = changenr()')
	let changenr = g:EasyDiff_tmp_out
	unlet g:EasyDiff_tmp_out
	return changenr
endfunction

" Workaround4_diff_hlID {{{1
" See 'Implementation Notes' Workaround4
" otherwinid: id of the other window (ie. window not current)
function! s:Workaround4_diff_hlID(otherwinid) abort
	call win_execute(a:otherwinid, 'noautocmd call diff_hlID(".", 1)')
endfunction

" Workaround6_diffupdate {{{1
" See 'Implementation Notes' Workaround6
" This function is also used in other contexts to enforce line correspondence.
function! s:Workaround6_diffupdate() abort
	" Current window decides the cursor position. If it has at least 1 line,
	" taking advantage of cursorbind, by toggling the cursor vertically,
	" bring cursor to the corresponding line in the other windows. If there
	" are no lines, we consider there is no correspondence.
	if s:FileSize() > 0
		call s:ToggleCursor()
	endif
endfunction

" Workaround8_delete {{{1
" See 'Implementation Notes' Workaround8. This is future proof, and will
" continue to work if :delete itself issues the correct message.
function! s:Workaround8_delete(msg, start, end) abort
	let deleted = a:end - a:start + 1
	" Positive lookahead @= ensures the count is captured correctly
	let reported = str2nr(matchstr(a:msg, '\v\d+%( line less| fewer lines)@='))
	if deleted <= &report || deleted == reported
		return a:msg
	endif
	let corrected_msg = deleted == 1 ? '1 line less' : deleted . ' fewer lines'
	if reported == 0
		return a:msg . "\n" . corrected_msg
	endif
	return substitute(a:msg, '\v\d+ (line less|fewer lines)', corrected_msg, '')
endfunction

" Workaround9_diffgetput {{{1
" See 'Implementation Notes' Workaround9.
" There are two ways to implement this: a) Use the change in file's line count
" and the original Diff size, to artificially create the report messages.
" Unfortunately, the only way to find the Diff size is to use
" s:JumpToDiffStart() and the expensive s:JumpToDiffEnd(), and then restore the
" pos. b) undo and then redo while capturing the latter's message. redo's
" message would have the same content as the one produced (if it were produced)
" by diffput/diffget. As both seem equally expensive, b) chosen for simplicity.
function! s:Workaround9_diffgetput(msg) abort
	" Future proof in case diffget/diffput are fixed to report the change,
	" by matching the pattern of native messages from standard line-editing
	" ex commands.
	let report_pattern = '\v\d+ (line less|fewer lines|more lines?|changes?)'
	if a:msg =~# report_pattern
		return a:msg
	endif
	" Close the undo-block
	noautocmd let &g:undolevels = &g:undolevels
	" undo once
	noautocmd silent undo
	" redo while capturing the message
	let diffmsg = trim(execute('noautocmd silent redo'))
	" append after stripping history/snapshot metadata. 'report' is not
	" honored intentionally, as the messages are useful to keep track of
	" the merges.
	return a:msg . "\n" . substitute(diffmsg, '\v; (after|before) #\d+.*', '', '')
endfunction

" Message {{{1
" Helper that removes Vim context from messages and adds highlighting.
" msg: The message to be printed
function! s:Message(msg) abort
	let lines = split(trim(a:msg), "\n")
	" Match window tag left: or right:
	let tag_pat = '^\d\+:\?$'
	" Match warnings like W10 or WED001
	let warn_pat = '^W[A-Z]*\d\+'

	" redraw to avoid the prompt 'Press ENTER or type command to continue'
	redraw
	let curwinnr = winnr()
	for line in lines
		" Remove Vim context
		let line = substitute(line, 'line\s\+\d\+:\s*\|Error.* function.*:.*', '', 'g')
		if empty(line)
			continue
		endif
		" highlight any tag
		let tag_match = matchstr(line, tag_pat)
		if !empty(tag_match)
			" str2nr ignores ':' suffix (if present) in tag_match
			if str2nr(tag_match) == curwinnr
				echohl EasyDiffWinTag
			else
				echohl EasyDiffWinTagNC
			endif
			echon tag_match
			echohl None
			echon ' '
			continue
		endif

		" highlight any warning
		if line =~# warn_pat
			echohl WarningMsg
			echon line
			echohl None
		else
			echon line
		endif
		echon ' '
	endfor
endfunction

" SortMessages {{{1
" Helper that removes Vim context from messages and adds highlighting.
" Helper that sorts a list of dict{'winnr':..., 'msg': ...} by winnr and prints
" msgs: The list of dicts
" Returns the sorted messages as a string
function! s:SortMessages(msgs) abort
	call sort(a:msgs, {a, b -> a.winnr - b.winnr})
	let str = ''
	for v in a:msgs
		let str .= "\n" . v.winnr . ":\n" . v.msg
	endfor
	return str
endfunction

" ResetUndoTracking {{{1
" Helper for various functions
" Clears the easydiff_undo_stack
" msg: Warning portion of the reset message.
function! s:ResetUndoTracking(msg) abort
	if empty(t:easydiff_undo_stack)
		return v:false
	endif
	let t:easydiff_undo_stack = []
	let msg = substitute(a:msg, '\v(WED\d+:[^\n]*)', '\1; Reset undo tracking', '')
	call s:Message(msg)
	return v:false
endfunction

" DiffStateValid {{{1
" Helper for various functions
" Validates the EasyDiff state
function! s:DiffStateValid() abort
	" Clear out previous messages
	echo ''
	" global diffopt should have filler enabled
	let msg = index(split(&diffopt, ','), 'filler') >= 0
				\ ? ''
				\ : "WED001: EasyDiff requires 'set diffopt+=filler'."

	let t:easydiff_curwinnr = winnr()
	let t:easydiff_otherwinnr = winnr('#')
	" If # is not a valid 'other' diff window, choose any other diff window
	if t:easydiff_otherwinnr == t:easydiff_curwinnr || !getwinvar(t:easydiff_otherwinnr, '&diff')
		let t:easydiff_otherwinnr = 0
	endif
	let t:easydiff_windows = 0
	let horizontal_splits = 0

	for winnr in range(1, winnr('$'))
		" Ignore non-diff windows
		if !getwinvar(winnr, '&diff')
			continue
		endif
		if !getwinvar(winnr, '&cursorbind')
			let msg .= "\n" . winnr . ":\nWED002: diff window requires 'set cursorbind'."
		endif
		let t:easydiff_windows += 1
		if t:easydiff_otherwinnr == 0 && winnr != t:easydiff_curwinnr
			let t:easydiff_otherwinnr = winnr
		endif
		if !exists('screenpos')
			let screenpos = win_screenpos(winnr)[0]
		else
			if screenpos != win_screenpos(winnr)[0]
				let horizontal_splits += 1
			endif
		endif
	endfor

	if t:easydiff_windows < 2
		let msg .= "\nWED003: At least two diff windows required."
	endif
	if horizontal_splits
		let msg .= "\nWED004: All diff windows must be in a single row of vertical splits."
	endif

	if !empty(msg)
		call s:Message(msg)
		return v:false
	endif
	return v:true
endfunction

" LinematchEnabled {{{1
" Helper for various functions
" Checks of diffopt contains linematch:{n}
function! s:LinematchEnabled() abort
	return &diffopt =~# '\<linematch'
endfunction

" RepresentsChanged {{{1
" Helper for various functions
" Checks if a:curline is Changed or Added. Note all lines in the Diff represent
" the same Diff
" curline: The line to be checked.
function! s:RepresentsChanged(curline) abort
	return diff_hlID(a:curline, 1) != 0
endfunction

" RepresentsFillerBefore {{{1
" Helper for various functions
" Checks if a:curline represents the preceding Filler
" curline: The line to be checked.
" Returns the number of fillers before (could be used in boolean contexts).
function! s:RepresentsFillerBefore(curline) abort
	" If Filler precedes, and either linematch is enabled or the preceding
	" line is not a Diff, curline represents the Filler. This takes into
	" account that, under diffopt linematch, any preceding Filler is a
	" separate Diff represented by curline; If linematch is not set,
	" preceding Filler is a Diff represented by curline only if previous
	" line to curline itself isn't a Added/Changed Diff. Note that exactly
	" one line in the buffer can represent one Filler.
	let filler_before = diff_filler(a:curline)
	return filler_before && (s:LinematchEnabled() || !s:RepresentsChanged(a:curline - 1))
				\ ? filler_before
				\ : 0
endfunction

" RepresentsFillerAfter {{{1
" Helper for various functions
" Checks if a:curline represents the following (EOF) Filler
" curline: The line to be checked.
" Returns the number of fillers after (could be used in boolean contexts).
function! s:RepresentsFillerAfter(curline) abort
	" If last line, and the 'virtual line' after shows Fillers, then
	" curline represents the EOF Filler. Note that no other line than the
	" last can represent the Filler after ('EOF Filler').
	return a:curline == line('$') ? diff_filler(a:curline + 1) : 0
endfunction


" RepresentsDiff {{{1
" Helper for various functions
" Checks if a:curline represents a valid Diff
" curline: The line to be checked.
function! s:RepresentsDiff(curline) abort
	return s:RepresentsChanged(a:curline) || s:RepresentsFillerBefore(a:curline) || s:RepresentsFillerAfter(a:curline)
endfunction

" StayOnDiff {{{1
" Helper for various functions
" In the current window, try to keep cursor on a Diff (ie. jump to next Diff if
" not already in a Diff).
function! s:StayOnDiff() abort
	if !g:easydiff_stay_on_diff
		return
	endif
	let pos = getcurpos()

	" Before diff_hlID() is used by s:RepresentsChanged() etc., execute
	" Workaround4.
	call s:Workaround4_diff_hlID(win_getid(t:easydiff_otherwinnr))
	if !s:RepresentsDiff(pos[1])
		" cursor not on a Diff, so has to move. One might prefer staying
		" on previous Added than advancing to next Diff. But that is
		" impossible to say reliably, as in n-way diff it is not a given
		" that Filler in otherwinnr has corresponding Added in curwinnr
		" and vice-versa. So just try moving to next Diff, failing which
		" jump to the previous(last) Diff.
		silent! keepjumps normal! ]c
		if pos[1] == line('.')
			silent! keepjumps normal! [c
		endif
		let pos[1] = line('.')
	endif
	" Restore column and curswant reset either by ]c and [c, or when window
	" is switched
	call s:CommitCursorMove(pos, pos[1], v:false)
	return v:true
endfunction

" RecordEdit {{{1
" Helper for EasyDiff undo tracking.
" curwinid	: id of window from where it is invoked
" changed_winid : id of window where the edit was made
" group(boolean): whether the edit should be grouped with another edit (used
"                 for atomic undo of two edits made by <S-Delete>
function! s:RecordEdit(curwinid, changed_winid, group) abort
	let changenr = a:curwinid == a:changed_winid ? changenr() : s:Workaround2_changenr(a:changed_winid)
	call add(t:easydiff_undo_stack, {'winid': a:changed_winid, 'changenr': changenr, 'grouped': a:group,})
	return v:true
endfunction

" Prompt {{{1
" Helper for s:MergeDiff() and s:DeleteDiffInAllWindows()
" msg		: prompt message
" options	: prompt options
function! s:Prompt(msg, options)
	let choice = confirm(a:msg, a:options, 0)
	if choice == 0
		call s:Message('Operation aborted')
	endif
	return choice
endfunction

" MergeDiffDispatcher {{{1
" Dispatcher for s:MergeDiff()
" right	: Merge away from (v:true), or towards (v:false) the target window
function! s:MergeDiffDispatcher(right) abort
	let spec = v:count1
	if !s:DiffStateValid()
		return v:false
	endif

	let l:right = a:right
	" The spec unambiguously encodes target and operating window numbers
	" (upto 99) as follows: If it has 1 digit, the it represents the target
	" window number, and the current window is assumed to be the operating
	" window. If it has 2 digits, the first/second digits represent the
	" target/operating window numbers. If it has 3 or 4 digits, the last two
	" digits represent the operating window number and the remaining leading
	" digits represent the target window number.
	if spec <= 9
		let operwinnr = t:easydiff_curwinnr
		if spec == 1 && t:easydiff_windows == 2
			" Simple directional merge for 2-way diff
			let targetwinnr = t:easydiff_otherwinnr
			if operwinnr < targetwinnr
				let l:right = !a:right
			endif
		else
			let targetwinnr = spec
		endif
		let restorewinnr = 0
	else
		if spec <= 99
			let operwinnr = spec % 10
			let targetwinnr = spec / 10
		elseif spec >= 100 && spec <= 9999
			let operwinnr = spec % 100
			let targetwinnr = spec / 100
		else
			echo 'count can have only upto 4 digits'
			return v:false
		endif
		let restorewinnr = operwinnr == t:easydiff_curwinnr ? 0 : t:easydiff_curwinnr
	endif

	if operwinnr < 1 || operwinnr > winnr('$')
		echo 'operating window number '. operwinnr . ' is invalid'
		return v:false
	endif
	if targetwinnr < 1 || targetwinnr > winnr('$')
		echo 'target window number '. targetwinnr . ' is invalid'
		return v:false
	endif
	if targetwinnr == operwinnr
		echo 'operating and target windows are the same'
		return v:false
	endif
	if !getwinvar(operwinnr, '&diff')
		echo 'operating window ' . operwinnr . ' is not in diff mode'
		return v:false
	endif
	if !getwinvar(targetwinnr, '&diff')
		echo 'target window ' . targetwinnr . ' is not in diff mode'
		return v:false
	endif

	if restorewinnr
		" Temporarily make operating window the current window
		execute 'noautocmd ' . operwinnr . 'wincmd w'
	endif
	let t:easydiff_otherwinnr = targetwinnr
	call s:MergeDiff(targetwinnr, operwinnr, l:right)
	if restorewinnr
		" Restore current window
		execute 'noautocmd ' . restorewinnr . 'wincmd w'
	endif
	return v:true
endfunction

" RangeCorrespondingToFillers {{{1
" Helper for MergeDiff() and DeleteDiffInAllWindows(). Find the range of lines
" in other window corresponding to the Filler before/after in current window.
" otherwinid : id of other window
" before : whether the filler is before current line
" winstart : screen row of filler start
" Returns the array with start, end lines in the range.
function! s:RangeCorrespondingToFiller(otherwinid, before, winstart) abort
	if a:before
		if s:FileSize() > 0
			let end = line('.', a:otherwinid)
			let winend = winline() - 1
			while end >= 1 && screenpos(a:otherwinid, end, 1).row > winend
				let end -= 1
			endwhile

			if end == 0
				" Invalidate range
				let start = 1
			else
				let start = end
				while start >= 1 && screenpos(a:otherwinid, start, 1).row > a:winstart
					let start -= 1
				endwhile
				if start >= 1 && screenpos(a:otherwinid, start, 1).row < a:winstart
					" We overshot due to filler. Increment start
					" even if it becomes >end and invalidates range.
					let start += 1
				endif
				" start == 0 is valid and equivalent to start == 1 in range
			endif
		else
			" When current window is empty, there is no
			" correspondence to line('.') and the entire other
			" window should be in range.
			let start = 1
			let end = s:WinEval(a:otherwinid, 's:FileSize()')
		endif
	else
		let start = line('.', a:otherwinid)
		let end = s:WinEval(a:otherwinid, 's:FileSize()')
		while start <= end && screenpos(a:otherwinid, start, 1).row < a:winstart
			let start += 1
		endwhile
	endif
	return [start, end]
endfunction

" MergeDiff {{{1
" Merge the current Diff
" otherwinnr : the target window for the merge
" curwinnr : the operating (current) window for the merge
" right(boolean): Whether the merge away or towards the other window.
function! s:MergeDiff(otherwinnr, curwinnr, right) abort
	let curwinid = win_getid(a:curwinnr)
	let otherwinid = win_getid(a:otherwinnr)
	let curline = line('.')
	let linematch = s:LinematchEnabled()
	let filler_before = s:RepresentsFillerBefore(curline)
	let changed = s:RepresentsChanged(curline)
	let filler_after = s:RepresentsFillerAfter(curline)

	" Corresponding line in other window may legally be in one of up to
	" three Diffs. For example, if filler_before && changed && filler_after,
	" the corresponding line may be in one of previous Added, current
	" Changed, or next Added. To be deterministic (matters when finding the
	" corresponding line in the other window), force exact line
	" correspondence using Workaround6_diffupdate(), even though here we are
	" really not working around an unexpected behavior.
	call s:Workaround6_diffupdate()

	" Below, diff represents the Diff be operated on the target window. It
	" is empty for the current window. For the other window, it is 'k' for
	" the previous Diff, and 'j' to for the last Diff. We need to set diff
	" for the 8 combinations of states, of filler_before, changed and
	" filler_after.
	let prev_diff = 'k'
	let next_diff = 'j'

	if !filler_before && changed && !filler_after
		let diff = ''
	elseif filler_before && !changed && !filler_after
		let diff = prev_diff
	elseif !filler_before && !changed && filler_after
		let diff = next_diff
	elseif filler_before && changed && !filler_after " only under linematch
		let choice = s:Prompt('In window ' . a:curwinnr . ', operate on the Previous or Current Diff?', "&Previous\n&Current")
		if choice == 0
			return v:false
		endif
		let diff = choice == 1 ? prev_diff : ''
	elseif !filler_before && changed && filler_after
		if linematch
			let choice = s:Prompt('In window ' . a:curwinnr . ', operate on the Current or Next Diff?', "&Current\n&Next")
			if choice == 0
				return v:false
			endif
			" See 'Implementation Notes' NOTE6
			let diff = choice == 1 ? '' : next_diff
		else " Combined changed and filler_after
			let diff = ''
		endif
	elseif filler_before && !changed && filler_after
		let choice = s:Prompt('In window ' . a:curwinnr . ', operate on the Previous or Next Diff?', "&Previous\n&Next")
		if choice == 0
			return v:false
		endif
		let diff = choice == 1 ? prev_diff : next_diff
	elseif filler_before && changed && filler_after " only under linematch
		let choice = s:Prompt('In window ' . a:curwinnr . ', operate on the Previous, Current or Next Diff?', "&Previous\n&Current\n&Next")
		if choice == 0
			return v:false
		endif
		let diff = choice == 1 ? prev_diff : (choice == 2 ? '' : next_diff)
	else " !filler_before && !changed && !filler_after
		call s:Message('Nothing to Merge: no Diff at cursor position in operating window ' . a:curwinnr)
		return v:false
	endif

	if empty(diff)
		" Operation can be performed from the current window
		let operwinid = curwinid
		if filler_after && has('nvim') && !has('nvim-0.12')
			" See 'Implementation Notes' Workaround5
			let pos = getcurpos()
			" Go to the start of diff to find the start position
			silent! normal! [c]c
			let action = printf('noautocmd silent %d,%d%s %d', line('.'), curline, (a:right ? 'diffget' : 'diffput'), winbufnr(a:otherwinnr))
			" Restore pos
			call s:CommitCursorMove(pos, pos[1], v:false)
		else
			" See 'Implementation Notes' NOTE2
			let action = printf('noautocmd silent %s %d', (a:right ? 'diffget' : 'diffput'), winbufnr(a:otherwinnr))
		endif
	else
		" For merging fillers, the opposite operation has to be
		" performed from the other window. Further for n-way diff, the
		" corresponding lines could belong to multiple Diffs (ie. unlike
		" in 2-way diff, not all of them might be Added). So line range
		" needs to be specified as well.
		let [otherstart, otherend] = s:RangeCorrespondingToFiller(otherwinid,
					\ diff ==# prev_diff,
					\ winline() + (diff ==# prev_diff ? -filler_before : 1))

		if otherstart > otherend
			call s:Message(printf('Nothing to Merge: Diff has only fillers in both operating (%d) and target (%d) windows', a:curwinnr, a:otherwinnr))
			return v:false
		endif

		let operwinid = otherwinid
		" See 'Implementation Notes' NOTE2
		let action = printf('noautocmd silent %d,%d%s %d', otherstart, otherend, (a:right ? 'diffput' : 'diffget'), winbufnr(a:curwinnr))
	endif

	if a:right
		let changed_winid = curwinid
		let msg = "\n" . a:otherwinnr . "\n->\n" . a:curwinnr . ":\n"
	else
		let changed_winid = otherwinid
		let msg = "\n" . a:curwinnr . "\n->\n" . a:otherwinnr . ":\n"
	endif

	let g:EasyDiff_tmp_in = operwinid == curwinid ? trim(execute(action)) : trim(win_execute(operwinid, action))
	" See 'Implementation Notes' Workaround9
	let msg .= changed_winid == curwinid ? s:Workaround9_diffgetput(g:EasyDiff_tmp_in) : s:WinEval(changed_winid, 's:Workaround9_diffgetput(g:EasyDiff_tmp_in)')
	unlet g:EasyDiff_tmp_in
	call s:RecordEdit(curwinid, changed_winid, v:false)

	diffupdate
	call s:Workaround6_diffupdate()
	call s:StayOnDiff()
	if !empty(msg)
		call s:Message(msg)
	endif
	return v:true
endfunction

" LastLineIsADifferentDiff {{{1
" Helper for s:DeleteDiffInAllWindows() and s:JumpToDiffEnd()
" When multiple Diffs (Changed, Added, Filler after) overlap at the last line,
" checks if the last line itself is a separate one line Diff.
function! s:LastLineIsADifferentDiff() abort
	" We know we are already at the last line, and that it is is Changed or
	" Added. But the last line may be preceded by a Filler or Unchanged,
	" return v:true if so. The check last == 1 is meaningful for
	" s:DeleteDiffInAllWindows()
	let last = line('.')
	if last == 1 || diff_filler(last) > 0 || !s:RepresentsChanged(last - 1)
		return v:true
	endif

	" The previous to last is also Changed or Added. We need to find if last
	" flipped from the previous. Since in n-way diff a Diff has the
	" smallest partition across all windows, it is sufficient to go through
	" the windows and find a single instance that indicates a flip.
	let winline = winline()
	let curwinnr = winnr()
	for winnr in range(1, winnr('$'))
		if winnr == curwinnr || !getwinvar(winnr, '&diff')
			continue
		endif
		let otherwinid = win_getid(winnr)
		let otherline = line('.', otherwinid)
		let otherwinline = screenpos(otherwinid, otherline, 1).row
		let otherfiller_before = s:WinEval(otherwinid, 'diff_filler(' . otherline . ')')
		let otherfiller_after = s:WinEval(otherwinid, 'diff_filler(' . (otherline+1) . ')')

		" last is a different Diff, if in any other diff window:
		" - otherwinline is one less than winline, and has fillers
		"   after: last flipped from Changed to Added.
		" - otherwinline is equal to winline, and has fillers before:
		"   last flipped from Added to Changed
		" - otherwinline is more than winline, offset exactly by fillers
		"   before: last flipped from Changed to Added.
		if (otherwinline == winline - 1 && otherfiller_after > 0)
					\ || (otherwinline == winline && otherfiller_before > 0)
					\ || (otherwinline > winline && otherwinline == winline + otherfiller_before)
			return v:true
		endif
	endfor
	return v:false
endfunction

" DeleteDiffInAllWindows {{{1
" Finds the full extent (including Fillers) of the Diff in current window, and
" deletes that extent from all diff Windows.
function! s:DeleteDiffInAllWindows() abort
	if !s:DiffStateValid()
		return v:false
	endif
	let curwinnr = t:easydiff_curwinnr
	let curwinid = win_getid(curwinnr)
	let curline = line('.')
	let linematch = s:LinematchEnabled()
	let filler_before = s:RepresentsFillerBefore(curline)
	let changed = s:RepresentsChanged(curline)
	let filler_after = s:RepresentsFillerAfter(curline)

	" Below 1 refers to the current window, and 2 the other. So start1 is
	" the starting line of Diff in the current window and so on.

	" Corresponding line in other window may legally be in one of up to
	" three Diffs. For example, if filler_before && changed && filler_after,
	" the corresponding line may be in one of previous Added, current
	" Changed, or next Added. To be deterministic (matters when finding the
	" corresponding line in the other window), force exact line
	" correspondence using Workaround6_diffupdate(), even though here we are
	" really not working around an unexpected behavior.
	call s:Workaround6_diffupdate()

	" Below, diff denotes the Diff to be deleted. It is empty for current
	" Diff, "k" for previous Diff(Added), "j" for for last Diff(Added). By
	" prompting the user if need be, we need to set diff for the 8
	" combinations of states, of filler_before, changed and filler_after.
	let prev_diff = 'k'
	let next_diff = 'j'

	if !filler_before && changed && !filler_after
		let diff = ''
	elseif filler_before && !changed && !filler_after
		let diff = prev_diff
	elseif !filler_before && !changed && filler_after
		let diff = next_diff
	elseif filler_before && changed && !filler_after " only under linematch
		let choice = s:Prompt('In window ' . curwinnr . ', operate on the Previous or Current Diff?', "&Previous\n&Current")
		if choice == 0
			return v:false
		endif
		let diff = choice == 1 ? prev_diff : ''
	elseif !filler_before && changed && filler_after
		if linematch
			let choice = s:Prompt('In window ' . curwinnr . ', operate on the Current or Next Diff?', "&Current\n&Next")
			if choice == 0
				return v:false
			endif
			let diff = choice == 1 ? '' : next_diff
		else " Combined changed and filler_after
			let diff = ''
		endif
	elseif filler_before && !changed && filler_after
		let choice = s:Prompt('In window ' . curwinnr . ', operate on the Previous or Next Diff?', "&Previous\n&Next")
		if choice == 0
			return v:false
		endif
		let diff = choice == 1 ? prev_diff : next_diff
	elseif filler_before && changed && filler_after " only under linematch
		let choice = s:Prompt('In window ' . curwinnr . ', operate on the Previous, Current or Next Diff?', "&Previous\n&Current\n&Next")
		if choice == 0
			return v:false
		endif
		let diff = choice == 1 ? prev_diff : (choice == 2 ? '' : next_diff)
	else " !filler_before && !changed && !filler_after
		call s:Message('In window ' . curwinnr . ', no Diff at cursor position to Delete')
		return v:false
	endif

	let extents = {}
	if empty(diff)
		" Changed has been chosen to be deleted. But if Changed and
		" Filler overlap at curline (which is also the last line), the
		" following JumpToDiffStart() will stay at curline by design. So
		" if curline isn't a separate one line Diff, nudge cursor up.
		if filler_after && !s:LastLineIsADifferentDiff()
			silent normal! k
		endif
		" curline may not be already at the start of Changed, so:
		call s:JumpToDiffStart(v:false)
		let start1 = line('.')
		let winstart1 = winline()

		for winnr in range(1, winnr('$'))
			if winnr == curwinnr || !getwinvar(winnr, '&diff')
				continue
			endif

			let otherwinid = win_getid(winnr)
			let extents[winnr] = {}
			let extents[winnr].start = line('.', otherwinid)
			let extents[winnr].winstart = screenpos(otherwinid, extents[winnr].start, 1).row
		endfor

		call s:JumpToDiffEnd(v:false)
		let end1 = line('.')
		let fillers1 = linematch ? 0 : diff_filler(end1 + 1)
		let winend1 = winline() + fillers1

		for winnr in keys(extents)
			let otherwinid = win_getid(winnr)
			let end2 = line('.', otherwinid)
			let winend2 = screenpos(otherwinid, end2, 1).row
			if extents[winnr].winstart > winend1 || winend2 < winstart1
				let extents[winnr].end = -1
			elseif winend2 > winend1
				" filler before
				let extents[winnr].end = end2 - 1
			else
				let last2 = line('$', otherwinid)
				while winend2 < winend1 && end2 < last2
					let nextwinend2 = screenpos(otherwinid, end2+1, 1).row
					if nextwinend2 - winend2 > 1
						" jump in screen row indicates filler before
						break
					endif
					let end2 += 1
					let winend2 = nextwinend2
				endwhile
				let extents[winnr].end = end2
			endif
		endfor
	else
		" curline represents the Filler before or Filler after: The
		" Filler before is a separate Diff - because if linematch is
		" enabled, it is so by design; Without linematch, the Filler is
		" not preceded by a Diff (as that would've resulted in curline
		" not representing the Filler). Similar reasoning applies to
		" Filler after ('EOF Filler'). So there is nothing to delete in
		" 1, invalidate its range.
		let start1 = 1
		let end1 = -1

		" starting screen row of filler
		let winstart1 = winline() + (diff ==# prev_diff ? -filler_before : 1)
		for winnr in range(1, winnr('$'))
			if winnr == curwinnr || !getwinvar(winnr, '&diff')
				continue
			endif
			let otherwinid = win_getid(winnr)
			let extents[winnr] = {}
			let [extents[winnr].start, extents[winnr].end] = s:RangeCorrespondingToFiller(otherwinid,
						\ diff ==# prev_diff,
						\ winstart1)
		endfor
	endif

	"See 'Implementation Notes' NOTE2
	let msgs = []
	let group = v:false
	if start1 <= end1
		" Delete in curwinid and RecordEdit
		let msg = trim(execute(printf('noautocmd silent %d,%ddelete', start1, end1)))
		let msg = s:Workaround8_delete(msg, start1, end1)
		if !empty(msg)
			call add(msgs, {'winnr': curwinnr, 'msg': msg})
		endif
		call s:RecordEdit(curwinid, curwinid, v:false)
		let group = v:true
	endif
	for winnr in keys(extents)
		let start2 = extents[winnr].start
		let end2 = extents[winnr].end
		let otherwinid = win_getid(winnr)
		if start2 <= end2
			" Delete in otherwinid and RecordEdit grouped with the previous
			let msg = trim(win_execute(otherwinid, printf('noautocmd silent %d,%ddelete', start2, end2)))
			let msg = s:Workaround8_delete(msg, start2, end2)
			if !empty(msg)
				call add(msgs, {'winnr': winnr, 'msg': msg})
			endif
			call s:RecordEdit(curwinid, otherwinid, group)
			let group = v:true
		endif
	endfor

	diffupdate
	call s:Workaround6_diffupdate()
	call s:StayOnDiff()
	call s:Message(s:SortMessages(msgs))
	return v:true
endfunction

" DeleteDiffInCurrentWindow {{{1
" Helper for s:DeleteAction()
function! s:DeleteDiffInCurrentWindow() abort
	if !s:DiffStateValid()
		return v:false
	endif
	if !s:JumpToDiffStart(v:false)
		call s:Message('Not inside a Diff')
		return v:false
	endif
	" Below 1 refers to the current window, and 2 the other. So start1 is
	" the starting line of Diff in the current window and so on.
	let curwinid = win_getid(t:easydiff_curwinnr)
	let start1 = line('.')
	call s:JumpToDiffEnd(v:false)
	let end1 = line('.')

	" Delete the Diff in current window and RecordEdit
	"See 'Implementation Notes' NOTE2
	let msg = trim(execute(printf('noautocmd silent %d,%ddelete', start1, end1)))
	let msg = s:Workaround8_delete(msg, start1, end1)
	call s:RecordEdit(curwinid, curwinid, v:false)

	diffupdate
	call s:Workaround6_diffupdate()
	call s:StayOnDiff()
	if !empty(msg)
		call s:Message("\n" . t:easydiff_curwinnr . ":\n" . msg)
	endif
	return v:true
endfunction

" PruneUndoMessages {{{1
" Helper for s:Undo(). Removes repeated time information from undo messages
function! s:PruneUndoMessages(msgs) abort
	let max_winnr = 0
	" Find the max winnr whose message will be presented fully
	for msg in a:msgs
		if max_winnr < msg.winnr
			let max_winnr = msg.winnr
		endif
	endfor

	" Remove timestamps from all other messages
	for msg in a:msgs
		if msg.winnr != max_winnr
			let msg.msg = substitute(msg.msg, '\s\+\(after\|before\)\s\+#\d\+\zs.*$', '', '')
		endif
	endfor
endfunction

" Undo {{{1
" Undoes edits tracked by EasyDiff (see s:RecordEdit())
function! s:Undo() abort
	if !s:DiffStateValid()
		return v:false
	endif
	if empty(t:easydiff_undo_stack)
		call s:Message('No tracked edit to undo')
		return v:false
	endif

	let msgs = []
	let curwinid = win_getid(t:easydiff_curwinnr)
	let action = 'noautocmd silent undo'
	while v:true
		let entry = t:easydiff_undo_stack[-1]
		let current_changenr = entry.winid == curwinid ? changenr() : s:WinEval(entry.winid, 'changenr()')

		if entry.changenr != current_changenr
			call s:PruneUndoMessages(msgs)
			" Proactive diffupdate preserves the next message. See
			" 'Implementation notes' NOTE5
			diffupdate
			let msg = 'WED010: Manual edit or undo detected'
			call add(msgs, {'winnr': win_id2win(entry.winid), 'msg': msg})
			return s:ResetUndoTracking(s:SortMessages(msgs))
		endif

		let msg = entry.winid == curwinid ? trim(execute(action)) : trim(win_execute(entry.winid, action))
		call add(msgs, {'winnr': win_id2win(entry.winid), 'msg': msg})
		call remove(t:easydiff_undo_stack, -1)
		if !entry.grouped
			break
		endif
	endwhile

	diffupdate
	" Decide cursor position based on the last undo (entry.winid)
	call win_execute(entry.winid, 'noautocmd call s:Workaround6_diffupdate()')
	call s:StayOnDiff()

	call s:PruneUndoMessages(msgs)
	call s:Message(s:SortMessages(msgs))
	return v:true
endfunction

" CommitCursorMove {{{1
" Helper for various functions
" Moves to new line, restores column/curswant and if mark is v:true, saves the
" previous position in jumplist.
" frompos: Previous value of getcurpos(). frompos[1] is set to toline.
" toline: New cursor line
" mark(boolean): Whether to save the previous position in jump list
function! s:CommitCursorMove(frompos, toline, mark) abort
	" See 'Implementation Notes' Workaround10.
	if a:frompos[1] != a:toline
		if a:mark
			call setpos('.', a:frompos)
			normal! m`
		endif
		let a:frompos[1] = a:toline
	endif
	" See 'Implementation Notes' Workaround11.
	call setpos('.', a:frompos)
	" curswant is a desired screen column for future vertical movements, and
	" setpos() or cursor() record it but don't honor it. As curswant
	" frompos[4] is screen col, and frompos[2] is byte index, there is no
	" clean way to force setpos() to honor curswant. So a subsequent | that
	" moves to screen column is needed.
	execute 'normal! ' . a:frompos[4] . '|'
endfunction

" JumpToDiffStart {{{1
" Also helper for various functions
" Jump to the first line of the current Diff
" verbose(boolean): Whether to issue a helpful message
function! s:JumpToDiffStart(verbose) abort
	let pos = getcurpos()
	if !s:RepresentsChanged(pos[1])
		if a:verbose
			call s:Message('Not inside a Diff')
		endif
		return v:false
	endif
	" Uses [c or ]c to find the diff start. The alternative is to scan
	" backwards with diff_hlID(), which is O(hunk size).
	if pos[1] < line('$')
		silent! keepjumps normal! j[c
	else
		" curline is the last line of file and Diff. If curline is the
		" only line in Diff (so the desired start of Diff also), [c goes
		" to start of the previous Diff, and subsequent ]c returns to
		" curline. If curline isn't the only line in this Diff, [c goes
		" to the start of this Diff and then the following ]c silently
		" fails. Finally if there is no previous Diff in file before
		" curline, [c silently fails, still staying at the 'start' of
		" this Diff. So in all cases we reach the start of this Diff
		" correctly.
		" NOTE: If curline represents multiple Diffs, say 'Changed' and
		" 'Filler after' ('EOF Filler'), then it is ambiguous as to
		" which Diff's start we should jump to. To be deterministic as a
		" Helper function, we remain at the 'EOF Filler's 'start'. This
		" also makes some sense when the Changed Diff is also of size 1.
		silent! normal! [c]c
	endif
	let curline = line('.')
	if a:verbose
		if pos[1] == curline
			call s:Message('Already at Diff start')
		else
			echo ''
		endif
	endif
	call s:CommitCursorMove(pos, curline, a:verbose)
	return v:true
endfunction

" JumpToDiffEnd {{{1
" Helper to various functions
" Jump to last line of the current Diff
" verbose(boolean): Whether to issue a helpful message
function! s:JumpToDiffEnd(verbose) abort
	let pos = getcurpos()
	let curline = pos[1]
	if !s:RepresentsChanged(curline)
		if a:verbose
			call s:Message('Not inside a Diff')
		endif
		return v:false
	endif

	" First find the line before the following Unchanged set, by scanning
	" forward with diff_hlID(), which is O(hunk size). Due to the presence
	" of Unchanged lines, there doesn't seem to be a more optimal solution
	" (considered ]c, diff folds etc.).
	let origin = curline
	let last = line('$')
	while curline < last && diff_hlID(curline + 1, 1) != 0
		let curline += 1
	endwhile

	if curline > origin
		" When diffopt includes linematch, each Added/Changed/Filler set
		" is a separate Diff even if adjacent. So there can be multiple
		" Diffs (Changed and/or Added) in the range [origin, curline].
		"
		" Without linematch, adjacent Added/Changed sets are
		" combined into a single Diff, so curline is the end of Diff.
		if s:LinematchEnabled()
			" Find lnum, the start of the next Diff
			noautocmd silent! keepjumps normal! ]c
			let next = line('.')
			if next > origin && next <= curline
				if next == last
					" last can represent multiple Diffs -
					" EOF Filler, this Diff's last line or
					" another one line Diff. Find if last
					" has broken ranks with the previous
					" lines (Changed to Added or Added to
					" Changed), and if it did, use its
					" preceding line as the end-of-Diff.
					let curline = s:LastLineIsADifferentDiff() ? (last - 1) : last
				else
					let curline = next - 1
				endif
			endif
		endif
		call s:CommitCursorMove(pos, curline, a:verbose)
		" See 'Implementation Notes' Workaround1.
		call s:ToggleCursor()
	endif
	if a:verbose
		if curline == origin
			call s:Message('Already at Diff end')
		else
			echo ''
		endif
	endif
	return v:true
endfunction

" JumpToFirstDiff {{{1
" ALso helper for s:HomeAction() and s:DiffModeSetup()
" Jump to the first line of the first Diff
" verbose(boolean): Whether to issue a helpful message
function! s:JumpToFirstDiff(verbose) abort
	let pos = getcurpos()
	" To go to the first line of the first Diff, we go to the first line,
	" next Diff, and then previous Diff. This accounts for the case where
	" the cursor is already inside the first Diff. silent! suppresses the
	" beep in vim
	silent! keepjumps normal! gg]c[c
	let curline = line('.')
	if s:RepresentsDiff(curline)
		if a:verbose
			if curline == pos[1]
				call s:Message('Already at first Diff')
			else
				echo ''
			endif
		endif
		call s:CommitCursorMove(pos, curline, a:verbose)
	else
		if a:verbose
			call s:Message('No Diff present')
		endif
		" Even if curline == pos[1], commit to restore column.
		call s:CommitCursorMove(pos, pos[1], v:false)
		if curline != pos[1]
			" See 'Implementation Notes' Workaround1.
			call s:ToggleCursor()
		endif
	endif
	return v:true
endfunction

" JumpToLastDiff {{{1
" Helper for s:EndAction()
" Jump to the first line of the last Diff.
" verbose(boolean): Whether to issue a helpful message
function! s:JumpToLastDiff(verbose) abort
	let pos = getcurpos()
	" To go to the first line of the last Diff, we go to the last line,
	" previous Diff, and then next Diff. This accounts for the case where
	" the cursor is already inside the last Diff. silent! suppresses the
	" beep in vim
	silent! keepjumps normal! G[c]c
	let curline = line('.')
	if s:RepresentsDiff(curline)
		if a:verbose
			if curline == pos[1]
				call s:Message('Already at last Diff')
			else
				echo ''
			endif
			call s:CommitCursorMove(pos, curline, a:verbose)
		endif
	else
		if a:verbose
			call s:Message('No Diff present')
		endif
		" Even if curline == pos[1], commit to restore column.
		call s:CommitCursorMove(pos, pos[1], v:false)
		if curline != pos[1]
			" See 'Implementation Notes' Workaround1.
			call s:ToggleCursor()
		endif
	endif
	return v:true
endfunction

" JumpToPreviousDiff {{{1
" Jump to the first line of the previous Diff
" verbose(boolean): Whether to issue a helpful message
function! s:JumpToPreviousDiff(verbose) abort
	" As v:count1 is reset by any normal mode command, save it upfront
	let repeat = v:count1
	let pos = getcurpos()
	call s:JumpToDiffStart(v:false)
	let oldline = line('.')
	execute 'silent! normal! ' . repeat . '[c'
	let curline = line('.')
	if curline == oldline
		if a:verbose
			call s:Message('No previous Diff to move to')
		endif
		if curline != pos[1]
			call s:CommitCursorMove(pos, pos[1], v:false)
			" See 'Implementation Notes' Workaround1.
			call s:ToggleCursor()
		endif
		return v:false
	endif
	call s:CommitCursorMove(pos, curline, a:verbose)
	if a:verbose
		echo ''
	endif
	return v:true
endfunction

" JumpToNextDiff {{{1
" Jump to the first line of the next Diff
" verbose(boolean): Whether to issue a helpful message
function! s:JumpToNextDiff(verbose) abort
	let pos = getcurpos()
	execute 'silent! normal! ' . v:count1 . ']c'
	let curline = line('.')
	if pos[1] == curline
		if a:verbose
			call s:Message('No next Diff to move to')
		endif
		return v:false
	endif
	call s:CommitCursorMove(pos, curline, a:verbose)
	if a:verbose
		echo ''
	endif
	return v:true
endfunction

" DeleteAction {{{1
" Overloaded <Delete> with preceding count
function! s:DeleteAction() abort
	if v:count1 == 1
		return s:DeleteDiffInCurrentWindow()
	else
		return s:DeleteDiffInAllWindows()
	endif
endfunction

" JumpToWindow {{{1
" Jump to window v:count1
function! s:JumpToWindow() abort
	let curwinnr = winnr()
	let otherwinnr = v:count1

	if otherwinnr < 1 || otherwinnr > winnr('$')
		echo 'Window ' . otherwinnr . ' does not exist'
		return v:false
	endif
	if otherwinnr == curwinnr
		echo 'Already in window ' . otherwinnr
		return v:false
	endif
	if !getwinvar(otherwinnr, '&diff')
		echo 'Skipping jump to non-diff window ' . otherwinnr
		return v:false
	endif

	" Force exact line correspondence
	call s:Workaround6_diffupdate()
	let t:easydiff_otherwinnr = curwinnr
	execute 'noautocmd ' . otherwinnr . 'wincmd w'
	call s:StayOnDiff()
	echo 'Jumped to window ' . otherwinnr
	return v:true
endfunction

" JumpToAlternateWindow {{{1
function! s:JumpToAlternateWindow() abort
	if !s:DiffStateValid()
		return v:false
	endif
	let otherwinnr = t:easydiff_otherwinnr

	" Force exact line correspondence
	call s:Workaround6_diffupdate()
	let t:easydiff_otherwinnr = t:easydiff_curwinnr
	execute 'noautocmd ' . otherwinnr . 'wincmd w'
	call s:StayOnDiff()
	echo 'Jumped to window ' . otherwinnr
	return v:true
endfunction

" HomeAction {{{1
" Overloaded <Home> with preceding count
function! s:HomeAction() abort
	if v:count1 == 1
		" v:count1 = 1 (no count) jumps to the first Diff
		return s:JumpToFirstDiff(v:true)
	else
		return s:JumpToAlternateWindow()
	endif
endfunction

" ToggleSetting {{{1
function! s:ToggleSetting(count1) abort
	if a:count1 == 2
		let g:easydiff_stay_on_diff = !g:easydiff_stay_on_diff
		echo 'g:easydiff_stay_on_diff ' . (g:easydiff_stay_on_diff ? 'enabled' : 'disabled')
	elseif a:count1 == 3
		" Toggle linematch in diffopt
		let linematch=matchstr(&diffopt, '\<linematch:\d\+\>')
		if empty(linematch)
			try
				if empty(s:saved_linematch)
					let s:saved_linematch='linematch:100'
				endif
				execute 'set diffopt+=' . s:saved_linematch
				echo s:saved_linematch . ' added to diffopt'
			catch
				let s:saved_linematch=''
				call s:Message('WED014: diffopt linematch is not supported by '. s:editor_version)
			endtry
		else
			let s:saved_linematch=linematch
			execute 'set diffopt-=' . linematch
			echo linematch . ' removed from diffopt'
		endif
	elseif a:count1 == 4
		" Toggle 'number'
		if &number == 0
			let cmd='setlocal number'
		else
			let cmd='setlocal nonumber'
		endif
		for winnr in range(1, winnr('$'))
			if getwinvar(winnr, '&diff')
				call win_execute(win_getid(winnr), 'noautocmd ' . cmd)
			endif
		endfor
		echo 'Executed "' . cmd . '" in diff windows'
	elseif a:count1 == 5
		" Toggle 'report'
		if &report
			let s:saved_report=&report
			let cmd='set report=0'
		else
			if s:saved_report == 0
				let s:saved_report = 2
			endif
			let cmd='set report=' . s:saved_report
		endif
		noautocmd execute cmd
		echo 'Executed "' . cmd . '"'
	elseif a:count1 == 6
		" Toggle 'list'
		if &list == 0
			let cmd='setlocal list'
		else
			let cmd='setlocal nolist'
		endif
		for winnr in range(1, winnr('$'))
			if getwinvar(winnr, '&diff')
				call win_execute(win_getid(winnr), 'noautocmd ' . cmd)
			endif
		endfor
		echo 'Executed "' . cmd . '" in diff windows'
	endif

	return v:true
endfunction

" EndAction {{{1
" Overloaded <End> with preceding count
function! s:EndAction() abort
	if v:count1 == 1
		" v:count1 = 1 (no count) moves cursor to the last Diff
		return s:JumpToLastDiff(v:true)
	endif
	return s:ToggleSetting(v:count1)
endfunction

" WithLazyredraw {{{1
" Helper for various functions, and usable directly as a mapping target (see
" s:easydiff_default_mappings). Calls a:Fn with 'lazyredraw' set, to hide from the
" user any intermediate screen updates a:Fn causes (eg. from cursorbind
" window sync during multi-step cursor movements). Any extra arguments are
" passed through to a:Fn; a:Fn's return value is passed back to the caller.
" Fn : Funcref to invoke
function! s:WithLazyRedraw(Fn, ...) abort
	let lazy = &lazyredraw
	set lazyredraw
	try
		return call(a:Fn, a:000)
	finally
		let &lazyredraw = lazy
	endtry
endfunction

" EasyDiff Commands {{{1
command! EasyDiffMergeDiffRight			call s:WithLazyRedraw(function('s:MergeDiffDispatcher'), v:true)
command! EasyDiffMergeDiffLeft			call s:WithLazyRedraw(function('s:MergeDiffDispatcher'), v:false)
command! EasyDiffDeleteDiffInCurrentWindow	call s:WithLazyRedraw(function('s:DeleteDiffInCurrentWindow'))
command! EasyDiffDeleteDiffInAllWindows		call s:WithLazyRedraw(function('s:DeleteDiffInAllWindows'))
command! EasyDiffUndo				call s:WithLazyRedraw(function('s:Undo'))
command! EasyDiffJumpToDiffStart		call s:WithLazyRedraw(function('s:JumpToDiffStart'), v:true)
command! EasyDiffJumpToDiffEnd			call s:WithLazyRedraw(function('s:JumpToDiffEnd'), v:true)
command! EasyDiffJumpToFirstDiff		call s:WithLazyRedraw(function('s:JumpToFirstDiff'), v:true)
command! EasyDiffJumpToLastDiff			call s:WithLazyRedraw(function('s:JumpToLastDiff'), v:true)
command! EasyDiffJumpToPreviousDiff		call s:WithLazyRedraw(function('s:JumpToPreviousDiff'), v:true)
command! EasyDiffJumpToNextDiff			call s:WithLazyRedraw(function('s:JumpToNextDiff'), v:true)
command! EasyDiffJumpToWindow			call s:WithLazyRedraw(function('s:JumpToWindow'))
command! EasyDiffJumpToAlternateWindow		call s:WithLazyRedraw(function('s:JumpToAlternateWindow'))
command! EasyDiffHelp				call s:WithLazyRedraw(function('s:ShowHelp'))
command! EasyDiffToggleStayOnDiff		call s:WithLazyRedraw(function('s:ToggleSetting'), 2)

" EasyDiff Default Mappings {{{1
" Single source of truth for EasyDiff default mappings; empty 'mode' is a
" comma separated list of n,x,s,o modes; empty 'noremap' implies remap.
let s:easydiff_default_mappings = [
      \ {'key': '<Right>',    'map': '<Cmd>EasyDiffMergeDiffRight<CR>',     'mode': 'n',   'noremap': 'nore'},
      \ {'key': '<Left>',     'map': '<Cmd>EasyDiffMergeDiffLeft<CR>',      'mode': 'n',   'noremap': 'nore'},
      \ {'key': '<Del>',      'map': '<Cmd>call <SID>DeleteAction()<CR>',   'mode': 'n',   'noremap': 'nore'},
      \ {'key': '<S-Del>',    'map': '2<Del>',                              'mode': 'n',   'noremap': '' },
      \ {'key': '<BS>',       'map': '<Cmd>EasyDiffUndo<CR>',               'mode': 'n',   'noremap': 'nore'},
      \ {'key': '<PageUp>',   'map': '<Cmd>EasyDiffJumpToDiffStart<CR>',    'mode': 'n,x', 'noremap': 'nore'},
      \ {'key': '<PageDown>', 'map': '<Cmd>EasyDiffJumpToDiffEnd<CR>',      'mode': 'n,x', 'noremap': 'nore'},
      \ {'key': '<Home>',     'map': '<Cmd>call <SID>HomeAction()<CR>',     'mode': 'n,x', 'noremap': 'nore'},
      \ {'key': '<S-Home>',   'map': '2<Home>',                             'mode': 'n',   'noremap': '' },
      \ {'key': '<End>',      'map': '<Cmd>call <SID>EndAction()<CR>',      'mode': 'n,x', 'noremap': 'nore'},
      \ {'key': '<S-End>',    'map': '2<End>',                              'mode': 'n',   'noremap': '' },
      \ {'key': '<Up>',       'map': '<Cmd>EasyDiffJumpToPreviousDiff<CR>', 'mode': 'n,x', 'noremap': 'nore'},
      \ {'key': '<Down>',     'map': '<Cmd>EasyDiffJumpToNextDiff<CR>',     'mode': 'n,x', 'noremap': 'nore'},
      \ {'key': '<Space>',    'map': '<Cmd>EasyDiffJumpToWindow<CR>',       'mode': 'n',   'noremap': 'nore'},
      \ {'key': '<F1>',       'map': '<Cmd>EasyDiffHelp<CR>',               'mode': 'n',   'noremap': 'nore'},
      \ ]

" DiffModeSetup {{{1
" Sets up EasyDiff mappings in diff windows and jumps to start of first Diff.
function! s:DiffModeSetup() abort
	if &diff && !exists('b:easydiff_saved_mappings')
		" 1. one-time global settings
		if empty(s:editor_version)
			if has('nvim')
				let s:editor_version = 'Neovim ' . matchstr(execute('version'), 'NVIM v\zs[^\n]*')
				if !has('nvim-0.12.0')
					call s:Message('WED008: EasyDiff untested on Neovim versions earlier than 0.12.0')
				endif
			else
				if exists('v:versionlong')
					let s:editor_version = 'Vim ' . printf('%d.%d.%d', v:versionlong / 1000000, (v:versionlong / 10000) % 100, v:versionlong % 10000)
				else
					let s:editor_version = 'Vim ' . printf('%d.%d', v:version / 100, v:version % 100)
				endif
				if v:version < 902
					call s:Message('WED009: EasyDiff untested on Vim versions earlier than 9.2')
				endif
			endif
			" Messages from :delete are suppressed when upto
			" 'report' lines are deleted. As these messages serve as
			" a feedback that is helpful especially in n-way diff,
			" setting report to 0, and letting the user toggle/set
			" it if needed.
			let s:saved_report = &report
			set report=0

			" highlight for window tags ('right:' or 'left:') in messages
			highlight link EasyDiffWinTag StatusLine
			highlight link EasyDiffWinTagNC StatusLineNC
			if !exists('g:easydiff_enable_default_mappings')
				let g:easydiff_enable_default_mappings = v:true
			endif
			if !exists('g:easydiff_stay_on_diff')
				let g:easydiff_stay_on_diff = v:true
			endif
		endif

		" 2. Buffer local settings that will be reverted when diff mode
		"    is toggled.
		" 2.1. A Non-zero scrolloff affects cursorbind which is vital to
		"      EasyDiff. See 'Implementation Notes' Workaround7. First
		"      save existing scrolloff.
		let b:easydiff_saved_scrolloff = &l:scrolloff
		let &l:scrolloff=0

		let b:easydiff_saved_statusline = &l:statusline
		let &l:statusline = '%{winnr()}: %<' . (empty(&l:statusline) ? &statusline : &l:statusline)

		" 2.2. Before creating EasyDiff mappings, save existing mappings
		let b:easydiff_saved_mappings = []
		if g:easydiff_enable_default_mappings
			for map in s:easydiff_default_mappings
				for mode in split(map.mode, ',')
					" Save any previous mapping, only IF it
					" was defined in this buffer. If global
					" or unmapped (ie. no prior buffer-local
					" mapping exists), mark it for unmapping
					" on nodiff.
					let map_info = maparg(map.key, mode, 0, 1)
					if empty(map_info) || !get(map_info, 'buffer', 0)
						let map_info = {'key': map.key, 'mode': mode, 'unmap': 1}
					endif
					call add(b:easydiff_saved_mappings, map_info)

					" Apply the buffer-local mapping
					execute mode . map.noremap . 'map <buffer> ' . map.key . ' ' . map.map
				endfor
			endfor
		endif
		call s:WithLazyRedraw(function('s:JumpToFirstDiff'), v:false)
	elseif !&diff && exists('b:easydiff_saved_mappings')
		" Restore scrolloff that we no longer need it to be 0
		let &l:scrolloff = b:easydiff_saved_scrolloff
		let &l:statusline = b:easydiff_saved_statusline

		for map_info in b:easydiff_saved_mappings
			if get(map_info, 'unmap', 0)
				" Remove mapping that had no prior buffer-local mapping
				execute map_info.mode . 'unmap <buffer> '. map_info.key
			else
				" Restore previous buffer-local mapping
				call mapset(map_info)
			endif
		endfor
		unlet b:easydiff_saved_mappings
	endif
endfunction

" DiffModeSetupInAllWindows {{{1
" Iterates over windows to invoke s:DiffModeSetup()
function! s:DiffModeSetupInAllWindows() abort
	for win in getwininfo()
		call win_execute(win.winid, 'noautocmd call <SID>DiffModeSetup()')
	endfor
	if getwinvar(winnr(), '&diff')
		" First diff in current window has the final say on cursor position
		call s:WithLazyRedraw(function('s:JumpToFirstDiff'), v:false)
	endif
endfunction

" augroup EasyDiff {{{1
augroup EasyDiff
	autocmd!
	" For dynamic toggling of diff mode
	autocmd OptionSet diff call s:DiffModeSetup()
	" For dynamically created windows
	autocmd WinEnter * call s:DiffModeSetup()

	" For calling s:DiffModeSetup() in all existing windows at the end of
	" all initializations. Needed for win_execute() commands.
	autocmd VimEnter * call s:DiffModeSetupInAllWindows()

	" Reset undo tracking when a new win->buf relationship is established,
	" or when a tracked window ceases to exist. v:vim_did_enter ensures
	" only events after initialization (VimEnter) are considered.
	autocmd BufWinEnter,WinClosed * if v:vim_did_enter | call s:ResetUndoTracking("WED015: Window or Buffer changed") | endif
augroup END
