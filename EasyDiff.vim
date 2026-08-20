"********************************************************************************
" Author  : Narendran Gopalakrishnan
" GitHub  : https://github.com/gnarendran/EasyDiff
" Usage   : source this Vim script anywhere in Vim/Neovim startup scripts, say
"           in vimrc ($XDG_CONFIG_HOME/vim/vimrc maybe) or init.nvim (say
"           $XDG_CONFIG_HOME/nvim/init.vim), or drop it in the plugin directory.
"********************************************************************************
" Introduction: {{{1
"   EasyDiff provides a simplified keyboard interface for resolving two-way
"   diffs in Vim and Neovim. It abstracts Vim's mnemonic diff commands behind an
"   intuitive cursor-key interface, simplifying navigation within and between
"   diffs and making repetitive merge, delete, and undo operations faster.
" Requirements: {{{1
"   - Requires Vim 9.2 or Neovim 0.11.6 (the tested versions). EasyDiff might
"     work in lower versions, but any issues found in lower versions are out of
"     scope of this plugin.
"   - Requires exactly two vertically split windows, both in diff mode. The
"     files may be opened directly using vim -d, nvim -d, or vimdiff, or by
"     manually invoking :diffthis in both vertical splits.
"   - Requires the default diff options `set cursorbind` and
"     `set diffopt+=filler` to remain unmodified.
" Key Bindings: {{{1
"   <Right>	- Merge Diff from the left window to the Right window (normal mode)
"   <Left>	- Merge Diff from the right window to the Left window (normal mode)
"   <Delete>	- Delete the Diff in the current window (normal mode)
"   <S-Delete>	- Delete the Diff in both windows (normal mode)
"   <Backspace>	- Undo the last Merge or Delete (normal mode)
"   <PageUp>	- Jump to the start of the current Diff (normal and visual modes)
"   <PageDown>	- Jump to the end of the current Diff (normal and visual modes)
"   <Home>	- Jump to the first Diff (normal and visual modes)
"   <End>		- Jump to the last Diff (normal and visual modes)
"   <Up>		- Jump to the previous Diff (accepts count) (normal and visual modes)
"   <Down>	- Jump to the next Diff (accepts count) (normal and visual modes)
"   <S-Home>	- Move cursor to the other window (normal mode)
"   <F1>		- Print this help message (normal mode)
"   Notes: {{{2
"   - The key bindings are restricted to the two diff'ed buffers.
"   - Other key bindings are not affected. Particularly,
"     `h`/`j`/`k`/`l`/`<C-f>`/`<C-b>`/`0`/`$`/`x` continue to provide the original
"     functions of `<Left>`/`<Down>`/`<Up>`/`<Right>`/`<PageDown>`/`<PageUp>`/`<Home>`/`<End>`/`<Delete>`.
"   - A Diff includes both modified text and deleted lines (Fillers). For
"     example to delete the lines in the right window that correspond to filler
"     lines in the left window, simply press <Right>. EasyDiff automatically
"     executes dp (or do from the right window) to produce the expected result.
"   - <Delete> deletes the Diff only in the current window. If the deleted Diff
"     is adjacent to an existing Filler, Vim/Neovim merges the new and existing
"     Fillers into a single, larger Diff. Then the new larger Diff may be merged
"     with the other window using <Left> or <Right>.
"   - <S-Delete> first finds the full extent of the Diff in current window,
"     including any Filler. Then it deletes this extent from both windows.
"   - <Backspace> Undoes both deletions performed by <S-Delete> in the two
"     windows, at once. To only undo one of those deletes, one has to manually
"     undo using 'u', but that will reset EasyDiff's undo tracking.
"   - <S-End> or 2<End> toggles variable g:easydiff_stay_on_diff; 3<End> toggles
"     'linematch' diffopt; 4<End> toggles 'set number'.
"   - <Home> jumps to the first Diff. At start, the cursor is automatically
"     positioned on the first Diff in the left window.
"   - <S-Home> Moves cursor to the corresponding line in the other window; once
"     there, move cursor as per variable g:easydiff_stay_on_diff. Vim/Neovim's
"     native <C-w>w could instead be used to switch windows without further
"     moving the cursor.
"   - If the terminal does not support the shifted keys <S-Home>, <S-Delete>, or
"     <S-End>, alternatives 2<Home>, 2<Delete>, or 2<End> may be used.
" Variables: {{{1
"    let g:easydiff_stay_on_diff = 1
"    - (Default) After a Diff Merge, Delete, Undo, or window switch, keep the
"      cursor on a Diff: if it is not already on a Diff, move it to the next
"      Diff; if there is no next Diff, move it to the last Diff.
"    let g:easydiff_stay_on_diff = 0
"    - After a Diff Merge, Delete, Undo or window switch, do not attempt to keep
"      the cursor on a Diff.
"
" Limitations: {{{1
"   - EasyDiff tracks the edits (Merges/Deletes) performed using <Right>,
"     <Left>, <Delete> or <S-Delete>, allowing them to be repeatedly undone
"     using <Backspace>. Performing any manual edit will reset this edit
"     tracking.
"   - The default key bindings may not suit all workflows. Mappings can be
"     customized inside s:DiffModeSetup()
"   - Non-zero scrolloff is known to affect cursorbind in some cases (for eg.
"     when one window is not able to scroll). As cursorbind is essential for
"     correct EasyDiff operations, it is recommended to keep the setting
"     `setlocal scrolloff=0` in both windows.
"   - Due to an upstream Vim/Neovim rendering quirk, an EOF filler may not be
"     visible by default even though EasyDiff tracks it correctly; press <C-e>
"     to reveal it.
" Implementation Notes: {{{1
" - Mapping Keys have been chosen to avoid confusion with normal editing
"   commands, especially accidental 'u' instead of the tracked undo of Diff
"   Merges and Deletes.
" - <Delete>, <Home> and <End> are overloaded with preceding count, due to
"   limited availability of keys (some terminals don't distinguish between
"   <Delete> and <S-Delete> etc.).
" - As only two vertically split windows are present, the left window has its
"   winnr() == 1, and the right, winnr() == 2.
" - curline refers to the line containing the cursor
" - diff mode enables 'cursorbind' which ensures that as curline in one window
"   changes, the curline in the other window also changes correspondingly. This
"   binding between the cursor keeps track of the Diff presentation. See
"   :help 'cursorbind'.
"   Workaround1: For Vim and Neovim issue: win_execute 'undo' does not trigger
"   cursorbind (cursor in the local window doesn't move), while win_execute of
"   the equivalent normal command 'normal! u' triggers cursorbind correctly.
"   Similarly, :delete and :call setpos() don't wake up cursorbind. But a
"   subsequent 'normal! kj' (or even 'echo ""') triggers cursorbind and forces
"   cursor synchronization.
" - In Vim/Neovim diff mode, curline is classified into four main categories
"   based on how it compares with its corresponding line in the other window:
"   changed:   Differs by at least one character. We refer to a set of
"              consecutive changed lines as 'Changed'
"   added:     Exists in this window, but not in the other. We refer to a set of
"              consecutive Added lines as 'Added'.
"   - curline is in Added or Changed, if and only if diff_hlID(curline, 1) != 0
"   unchanged: Identical in both windows. curline is unchanged if and only if
"              diff_hlID(curline, 1) == 0
"   deleted:   Does not exist in this window, but exists in the other.
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
"   - The command 'dp' merges 'Current Diff' *to* the other window
"   - The command 'do' merges 'Current Diff' *from* the other window
"
"   As defined there cannot be a curline following the 'EOF Filler'. So if the
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
"   extent in the other window. To have <Backspace> undo <S-Delete> atomically,
"   both the windows are undone as a group.
" - Ref :help undo-blocks : Consecutive edits performed in the *other* window
"   via win_execute() and similarly via dp, remain in a single undo block with
"   the same changenr(). To force every Diff Merge into its own undo block (and
"   thus a different changenr()) after a Merge to the other window, the
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
" - Workaround4: For Vim/Neovim-0.11.6 bug (likely fixed in Neovim-0.12.0):
"   After a Merge/Undo and a further diffupdate, in some cases subsequent
"   diff_hlID computes wrong, until rendered. Computing it once before that in
"   the other window makes the value come out right.
" - Workaround5: For Neovim-0.11.6 bug fixed in Neovim-0.12.0: If a Diff
"   precedes 'EOF Filler', a 'do' on the Diff also does a 'do' on the Filler.
"   Instead executing a 'dp' from the other window gives the expected result.
" - Workaround7: In both Vim and Neovim, a non-zero scrolloff (say scrolloff=999
"   to center the cursor), makes cursorbind go wrong, mostly when a window
"   cannot scroll more. Couldn't find a workaround other than forcing
"   'setlocal scrolloff=999'
" - edits and undo's by commands other than the standard diff commands (like do,
"   dp, [c, ]c etc.), can leave the diff display temporarily stale and out of
"   sync. So a subsequent message might disappear when an auto diffupdate/redraw
"   syncs the diff. To workaround, proactively diffupdate after edits/undo's,
"   before a echo/echomsg.
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
" - NOTE2: Messages from 'do'/'dp' like 'W10: Warning: Changing a readonly file'
"   aren't exceptions. But when invoked from within functions, they are printed
"   with Vim's function context which we don't need. So silent is used to
"   suppress the original output, and then s:Message() redisplays them without
"   Vim's function context.
" - NOTE3: There is a bug in Vim 9.2.390 and Neovim 0.12.4, fixed in later
"   versions of Vim/Neovim, involving :diffget (normal do) into an empty buffer.
"   See:
"   https://github.com/vim/vim/issues/20950
"   https://github.com/neovim/neovim/issues/41172
" - Both in Vim and Neovim, :delete reports one fewer line when deleting the
"   entire buffer, but :undo on an empty buffer reports correctly. See:
"   https://github.com/vim/vim/issues/21049
"   https://github.com/neovim/neovim/issues/41306
"   Workaround8: When :delete results in an empty buffer, correct its message in
"   line with :undo, while honoring 'report' (see :h 'report') as well.
" - :diffget and :diffput (normal do and dp) do not report back the changes made
"   ('1 line less', '2 more lines', '3 changes' etc.), unlike other ex commands.
"   Workaround9: Emulate the messages that ought to have been generated by these
"   commands.

" Variables {{{1
" After a Merge/Delete/Undo the cursor might not be on a Diff. The following
" option decides if the cursor should then go to the next Diff (failing which
" the last Diff).
let g:easydiff_stay_on_diff = v:true
let s:thisfile = expand('<sfile>:p')
let s:saved_linematch=''
let s:editor_version = ''
" Stack of tracked Diff Merges and Deletes.
" Each entry is {'winid': ..., 'changenr': ..., 'grouped': ...}.
" 'grouped' means "undo this entry and continue the undo loop to the
" next (earlier) entry, rather than stopping." For a <S-Delete>, the
" later-pushed entry is grouped:true; the earlier-pushed one is
" grouped:false, marking where the compound undo should stop.
" Undo() only succeeds if the buffer is still at the changenr.
let s:undo_stack = []
" leftwinid and rightwinid used to validate the integrity of undo_stack
let s:leftwinid = ''
let s:rightwinid = ''
" lefttag and righttag used to highlight messages from respective windows
let s:lefttag = "\nleft:\n"
let s:righttag = "\nright:\n"

" ShowHelp {{{1
" Presents the help information from the beginning of this file
function! s:ShowHelp() abort
	let l:lines = readfile(s:thisfile)

	let l:start = -1
	let l:end = len(l:lines)

	" Find the markers.
	for l:i in range(len(l:lines))
		if l:start < 0 && l:lines[l:i] =~# '^" Introduction:'
			let l:start = l:i+1
		elseif l:start >= 0 && l:lines[l:i] =~# '^" Implementation Notes'
			let l:end = l:i
			break
		endif
	endfor

	if l:start < 0
		call s:Message('WED011: "Introduction:" help section not found')
		return
	endif

	let l:title = 'EasyDiff on ' . s:editor_version
	" Initialize with title and a decorator
	let l:help = [l:title, substitute(l:title, '.', '‾', 'g')]
	" Add help text after removing leading comment prefix, and trailing {{{ fold marker
	let l:help += map(copy(l:lines[l:start : l:end - 1]),
				\ {_, v -> substitute(v, '^\s*"\s\|\s*{{{\d\+.*$', '', 'g')})
	echo join(l:help, "\n")
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
" winid (optional): id of the edited window; defaults to id of current window
" Even though win_execute could be used on winid without distinguishing between
" current and other window, we do make that distinction as mostly current window
" is the target, where we can avoid the overhead of win_execute.
function! s:Workaround6_diffupdate(...) abort
	if a:0 == 0 || a:1 == win_getid()
		" current window decides the cursor position
		if line("$") > 1
			" At least two lines present: Taking advantage of
			" cursorbind, by toggling the cursor vertically, bring
			" cursor to the corresponding line in the other window.
			execute 'noautocmd silent normal! ' . (line(".") == 1 ? "jk" : "kj")
		elseif !empty(getline(1))
			" There is exactly one line: cursor cannot of course
			" vertically move, so use the number of preceding
			" fillers to decide the cursor position in the other
			" window.
			let otherwinid = win_getid(winnr() == 1 ? 2 : 1)
			let curline = diff_filler(1) + 1
			call win_execute(otherwinid, 'noautocmd silent normal! ' . curline . 'G')
		endif
		" if there are no lines, we consider there is no correspondence.
		return
	endif

	" otherwinid is the source of truth of the cursor position. The logic
	" is similar to the above, but with roles of current and other window
	" reversed.
	let otherwinid = a:1
	if s:WinEval(otherwinid, 'line("$")') > 1
		call win_execute(otherwinid, 'noautocmd execute "silent normal! " . (line(".") == 1 ? "jk" : "kj")')
	elseif s:WinEval(otherwinid, '!empty(getline(1))')
		let curline = s:WinEval(otherwinid, 'diff_filler(1)') + 1
		execute 'noautocmd silent normal! ' . curline . 'G'
	endif
endfunction

" Workaround8_delete {{{1
" See 'Implementation Notes' Workaround8. This is future proof, and will
" continue to work if :delete itself issues the correct message.
function! s:Workaround8_delete(msg, start, end) abort
	let l:deleted = a:end - a:start + 1
	" Positive lookahead @= ensures the count is captured correctly
	let l:reported = str2nr(matchstr(a:msg, '\v\d+%( line less| fewer lines)@='))
	if l:deleted <= &report || l:deleted == l:reported
		return a:msg
	endif
	let l:corrected_msg = l:deleted == 1 ? '1 line less' : l:deleted . ' fewer lines'
	if l:reported == 0
		return a:msg . "\n" . l:corrected_msg
	endif
	return substitute(a:msg, '\v\d+ (line less|fewer lines)', l:corrected_msg, '')
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
	let l:report_pattern = '\v\d+ (line less|fewer lines|more lines?|changes?)'
	if a:msg =~# l:report_pattern
		return a:msg
	endif
	" Close the undo-block
	noautocmd let &g:undolevels = &g:undolevels
	let l:lazy = &lazyredraw
	set lazyredraw
	" undo once
	noautocmd silent undo
	" redo while capturing the message
	let diffmsg = trim(execute('noautocmd silent redo'))
	let &lazyredraw = l:lazy
	" append after stripping history/snapshot metadata. 'report' is not
	" honored intentionally, as the messages are useful to keep track of
	" the merges.
	return a:msg . "\n" . substitute(diffmsg, '; after.*', '', '')
endfunction

" Message {{{1
" Helper that removes Vim context from messages and adds highlighting.
" msg: The message to be printed
function! s:Message(msg) abort
	let l:lines = split(trim(a:msg), "\n")
	" Match window tag left: or right:
	let l:tag_pat = '^\%(left:\|right:\)$'
	" Match warnings like W10 or WED001
	let l:warn_pat = '^W[A-Z]*\d\+'

	" redraw to avoid the prompt 'Press ENTER or type command to continue'
	redraw
	for l:line in l:lines
		" Remove Vim context
		let l:line = substitute(l:line, 'line\s\+\d\+:\s*\|Error.* function.*:.*', '', 'g')
		if empty(l:line)
			continue
		endif
		" highlight any tag
		let l:tag_match = matchstr(l:line, l:tag_pat)
		if !empty(l:tag_match)
			echohl EasyDiffWindowTag
			echon l:tag_match
			echohl None
			echon ' '
			continue
		endif

		" highlight any warning
		if l:line =~# l:warn_pat
			echohl WarningMsg
			echon l:line . '. '
			echohl None
		else
			echon l:line . '. '
		endif
	endfor
endfunction

" ResetUndoTracking {{{1
" Helper for various functions
" Clears the undo_stack
" msg: Warning portion of the reset message.
function! s:ResetUndoTracking(msg) abort
	let s:undo_stack = []
	call s:Message(a:msg)
	return v:false
endfunction

" DiffStateValid {{{1
" Helper for various functions
" Validates the EasyDiff state
function! s:DiffStateValid() abort
	" clear out previous messages
	echo ''
	" Exactly two diff windows?
	if winnr('$') != 2
		return s:ResetUndoTracking('WED001: EasyDiff requires exactly two windows; Reset undo tracking')
	endif
	" Both must be diff windows.
	if !getwinvar(1, '&diff') || !getwinvar(2, '&diff')
		return s:ResetUndoTracking('WED002: EasyDiff requires both windows to be in diff mode; Reset undo tracking')
	endif
	" Both must have cursorbind set.
	if !getwinvar(1, '&cursorbind') || !getwinvar(2, '&cursorbind')
		return s:ResetUndoTracking('WED003: EasyDiff requires ''set cursorbind'' in both windows; Reset undo tracking')
	endif
	if index(split(&diffopt, ','), 'filler') < 0
		return s:ResetUndoTracking('WED004: EasyDiff requires ''set diffopt+=filler''; Reset undo tracking')
	endif
	" Must be a vertical split (same top row).
	if win_screenpos(1)[0] != win_screenpos(2)[0]
		return s:ResetUndoTracking('WED005: EasyDiff requires vertical diff split; Reset undo tracking')
	endif

	let l:curleftwinid = win_getid(1)
	let l:currightwinid = win_getid(2)
	if empty(s:leftwinid) || empty(s:rightwinid)
		if !empty(s:undo_stack)
			" Cannot happen; ResetUndoTracking and continue
			call s:ResetUndoTracking('WED006: Inconsistent state of window(s); Reset undo tracking')
		endif
		let s:leftwinid = l:curleftwinid
		let s:rightwinid = l:currightwinid
	elseif s:leftwinid != l:curleftwinid || s:rightwinid != l:currightwinid
		let s:leftwinid = l:curleftwinid
		let s:rightwinid = l:currightwinid
		return s:ResetUndoTracking('WED007: One or both windows changed; Reset undo tracking')
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
	let otherwinid = win_getid(winnr() == 1 ? 2 : 1)
	let curline = line('.')

	" Before diff_hlID() is used by s:RepresentsChanged() etc., execute
	" Workaround4.
	call s:Workaround4_diff_hlID(otherwinid)
	if !s:RepresentsDiff(curline)
		" cursor not on a Diff, so has to move. Prefer staying on
		" previous Added than advancing to next Diff.
		if s:WinEval(otherwinid, 's:RepresentsFillerBefore(line("."))')
			silent normal! k
		else
			" Try moving to next Diff, failing which jump to the
			" previous(last) Diff.
			silent! normal! ]c
			if curline == line('.')
				silent! normal! [c
			endif
		endif
	endif
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
	call add(s:undo_stack, {'winid': a:changed_winid, 'changenr': changenr, 'grouped': a:group,})
	return v:true
endfunction

" Prompt {{{1
" Helper for s:MergeDiff() and s:DeleteDiffInBothWindows()
" msg		: prompt message
" options	: prompt options
function! s:Prompt(msg, options)
	let choice = confirm(a:msg, a:options, 0)
	if choice == 0
		call s:Message('Operation aborted')
	endif
	return choice
endfunction

" MergeDiff {{{1
" Merge the current Diff
" right(boolean): Whether the merge is towards the right or the left window.
function! s:MergeDiff(right) abort
	if !s:DiffStateValid()
		return v:false
	endif
	let curwinnr = winnr()
	let curwinid = win_getid(curwinnr)
	let otherwinid = win_getid(curwinnr == 1 ? 2 : 1)
	let curline = line('.')
	let linematch = s:LinematchEnabled()
	let filler_before = s:RepresentsFillerBefore(curline)
	let changed = s:RepresentsChanged(curline)
	let filler_after = s:RepresentsFillerAfter(curline)

	" Corresponding line in other window may legally be in one of up to
	" three Diffs. For example, if filler_before && changed && filler_after,
	" the corresponding line may be in one of previous Added, current
	" Changed, or next Added. To be deterministic, force exact line
	" correspondence using Workaround6_diffupdate(), even though here we are
	" really not working around an unexpected behavior.
	call s:Workaround6_diffupdate()

	" Below, action represents the initial command to be executed on the
	" target window. It is empty for the current window. For the other
	" window, it is 'k' to go to the previous Diff(Added), and 'j' to go to
	" the last Diff(Added). We need to set action for the 8 combinations of
	" states, of filler_before, changed and filler_after.
	let prev_diff = 'k'
	let next_diff = 'j'

	if (!filler_before && changed && !filler_after)
				\ || (filler_before && !changed && !filler_after)
				\ || (!filler_before && !changed && filler_after)
		let action = ''
	elseif filler_before && changed && !filler_after " only under linematch
		let choice = s:Prompt('Operate on Previous or Current Diff?', "&Previous\n&Current")
		if choice == 0
			return v:false
		endif
		let action = choice == 1 ? prev_diff : ''
	elseif !filler_before && changed && filler_after
		if linematch
			let choice = s:Prompt('Operate on Current or Next Diff?', "&Current\n&Next")
			if choice == 0
				return v:false
			endif
			" See 'Implementation Notes' Workaround5: Switch 'do' to
			" 'dp' from the other window, by initializing action
			" with a no-op jk
			if has('nvim') && !has('nvim-0.12')
				let action = choice == 1 ? 'jk' : next_diff
			else
				let action = choice == 1 ? '' : next_diff
			endif
		else " Combined changed and filler_after
			let action = ''
		endif
	elseif filler_before && !changed && filler_after
		let choice = s:Prompt('Operate on Previous or Next Diff?', "&Previous\n&Next")
		if choice == 0
			return v:false
		endif
		let action = choice == 1 ? prev_diff : next_diff
	elseif filler_before && changed && filler_after " only under linematch
		let choice = s:Prompt('Operate on Previous, Current or Next Diff?', "&Previous\n&Current\n&Next")
		if choice == 0
			return v:false
		endif
		let action = choice == 1 ? prev_diff : (choice == 2 ? '' : next_diff)
	else " !filler_before && !changed && !filler_after
		call s:Message('No Diff at cursor position to Merge')
		return v:false
	endif

	if empty(action)
		" Operation can be performed from the current window
		let targetwinid = curwinid
		" See 'Implementation Notes' NOTE2
		let action = 'noautocmd silent normal! ' . (a:right ? (curwinnr == 1 ? 'dp' : 'do') : (curwinnr == 1 ? 'do' : 'dp'))
	else
		" Opposite operation has to be performed from the other window
		let targetwinid = otherwinid
		" See 'Implementation Notes' NOTE2
		let action = 'noautocmd silent normal! ' . action . (a:right ? (curwinnr == 1 ? 'do' : 'dp') : (curwinnr == 1 ? 'dp' : 'do'))
	endif

	let changed_winid = a:right ? (curwinnr == 1 ? otherwinid : curwinid) : (curwinnr == 1 ? curwinid : otherwinid)
	let g:EasyDiff_tmp_in = targetwinid == curwinid ? trim(execute(action)) : trim(win_execute(targetwinid, action))
	" See 'Implementation Notes' Workaround9
	let l:msg = changed_winid == curwinid ? s:Workaround9_diffgetput(g:EasyDiff_tmp_in) : s:WinEval(changed_winid, 's:Workaround9_diffgetput(g:EasyDiff_tmp_in)')
	unlet g:EasyDiff_tmp_in
	call s:RecordEdit(curwinid, changed_winid, v:false)
	call s:StayOnDiff()
	if !empty(l:msg)
		call s:Message((changed_winid == s:leftwinid ? s:lefttag : s:righttag) . l:msg)
	endif
	return v:true
endfunction

" EOFFillers {{{1
" Helper for EndRepresentsAdded
" Returns the number of EOF Fillers
function! s:EOFFillers() abort
	let last = line('$')
	" Find the virtual line that follows the EOF Fillers. If the buffer is
	" empty, virt_line is 1, otherwise line('$')+1. This distinction is
	" needed as line('$') == 1 even for an empty buffer.
	let virt_line = last == 1 && empty(getline(1)) ? 1 : last + 1
	return diff_filler(virt_line)
endfunction

" EndRepresentsAdded {{{1
" Helper for DeleteDiffInBothWindows; Expensive test used as a last resort to
" find if line('.') that is already known to be the end of a Diff, is a Added
" line.
" Returns v:true if line('.') is Added; v:false otherwise
function! s:EndRepresentsAdded() abort
	" other window's curline can represent a single Changed line, or a one
	" line Filler, and both can legally correspond to this end of Diff in 1.
	" Decide by going to the next line in 1 and checking if line('.')
	" changes in 2.
	let otherwinid = win_getid(winnr() == 1 ? 2 : 1)
	if line('.') < line('$')
		let other_curline = s:WinEval(otherwinid, 'line(".")')
		noautocmd silent normal! j
		let res = other_curline == s:WinEval(otherwinid, 'line(".")')
		noautocmd silent normal! k
	else
		let res = s:WinEval(otherwinid, 's:EOFFillers() > 0')
	endif
	return res
endfunction

" DeleteDiffInBothWindows {{{1
" Finds the full extent (including Fillers) of the Diff in current window, and
" deletes that extent from both Windows.
function! s:DeleteDiffInBothWindows() abort
	if !s:DiffStateValid()
		return v:false
	endif
	let curwinnr = winnr()
	let curwinid = win_getid(curwinnr)
	let otherwinid = win_getid(curwinnr == 1 ? 2 : 1)
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
	" Changed, or next Added. To be deterministic, force exact line
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
		let choice = s:Prompt('Operate on Previous or Current Diff?', "&Previous\n&Current")
		if choice == 0
			return v:false
		endif
		let diff = choice == 1 ? prev_diff : ''
	elseif !filler_before && changed && filler_after
		if linematch
			let choice = s:Prompt('Operate on Current or Next Diff?', "&Current\n&Next")
			if choice == 0
				return v:false
			endif
			let diff = choice == 1 ? '' : next_diff
		else " Combined changed and filler_after
			let diff = ''
		endif
	elseif filler_before && !changed && filler_after
		let choice = s:Prompt('Operate on Previous or Next Diff?', "&Previous\n&Next")
		if choice == 0
			return v:false
		endif
		let diff = choice == 1 ? prev_diff : next_diff
	elseif filler_before && changed && filler_after " only under linematch
		let choice = s:Prompt('Operate on Previous, Current or Next Diff?', "&Previous\n&Current\n&Next")
		if choice == 0
			return v:false
		endif
		let diff = choice == 1 ? prev_diff : (choice == 2 ? '' : next_diff)
	else " !filler_before && !changed && !filler_after
		call s:Message('No Diff at cursor position to Delete')
		return v:false
	endif

	if empty(diff)
		" curline represents a Changed set: curline may not be already
		" at the start of Changed, so first:
		call s:JumpToDiffStart(v:false)
		let start1 = line('.')
		let start2 = s:WinEval(otherwinid, 'line(".")')

		call s:JumpToDiffEnd(v:false)
		let end1 = line('.')
		let fillers1 = linematch ? 0 : diff_filler(end1 + 1)

		if fillers1 > 0
			" In 2, there are at least some Added lines to delete,
			" but no Filler
			let end2 = start2 + end1 - start1 + fillers1
		else
			" In 2, there could be some fillers and end2 has to be
			" invalidated if there is nothing to delete, or
			" decremented if it represents a Filler before. The
			" following clauses apply with or without linematch.
			let end2 = s:WinEval(otherwinid, 'line(".")')
			let fillers2_before = s:WinEval(otherwinid, 'diff_filler(' . end2 . ')')
			if end2 > start2
				if fillers2_before > 0
					let end2 -= 1
				endif
			else " end2 == start2
				if end1 > start1
					" filler2_before fully corresponds to
					" the Diff in 1.
					let end2 = -1
				else " end1 == start1
					if fillers2_before == 1
						" either the filler2_before or end2
						" could correspond to the Diff in 1
						" As a last resort tie-break
						" using this call:
						if s:EndRepresentsAdded()
							let end2 = -1
						endif
					endif
				endif
			endif
		endif
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
		if diff ==# prev_diff
			if s:FileSize() > 0
				let end2 = s:WinEval(otherwinid, 'line(".")') - 1
				let start2 = end2 - filler_before + 1
			else
				" When 1 is empty, there is no correspondence to
				" line('.') and the entire 2 should be deleted.
				let start2 = 1
				let end2 = filler_before
			endif
		else " diff ==# next_diff ('EOF Filler')
			let start2 = s:WinEval(otherwinid, 'line(".")') + 1
			let end2 = start2 + filler_after - 1
		endif
	endif

	"See 'Implementation Notes' NOTE2
	let l:leftmsg = ''
	let l:rightmsg = ''
	if start1 <= end1
		" Delete in curwinid and RecordEdit
		let l:msg = trim(execute(printf('noautocmd silent %d,%ddelete', start1, end1)))
		let l:msg = s:Workaround8_delete(l:msg, start1, end1)
		call s:RecordEdit(curwinid, curwinid, v:false)
		if !empty(l:msg)
			if curwinid == s:leftwinid
				let l:leftmsg = s:lefttag . l:msg
			else
				let l:rightmsg = s:righttag . l:msg
			endif
		endif
	endif
	if start2 <= end2
		" Delete in otherwinid and RecordEdit grouped with the previous
		let l:msg = trim(win_execute(otherwinid, printf('noautocmd silent %d,%ddelete', start2, end2)))
		let l:msg = s:Workaround8_delete(l:msg, start2, end2)
		call s:RecordEdit(curwinid, otherwinid, start1 <= end1)
		if !empty(l:msg)
			if otherwinid == s:leftwinid
				let l:leftmsg = s:lefttag . l:msg
			else
				let l:rightmsg = s:righttag . l:msg
			endif
		endif
	endif

	" As this edit wasn't a diff operation, force diffupdate
	diffupdate
	call s:Workaround6_diffupdate()
	call s:StayOnDiff()
	call s:Message(l:leftmsg . l:rightmsg)
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
	let curwinid = win_getid()
	let start1 = line('.')
	call s:JumpToDiffEnd(v:false)
	let end1 = line('.')

	" Delete the Diff in current window and RecordEdit
	"See 'Implementation Notes' NOTE2
	let l:msg = trim(execute(printf('noautocmd silent %d,%ddelete', start1, end1)))
	let l:msg = s:Workaround8_delete(l:msg, start1, end1)
	call s:RecordEdit(curwinid, curwinid, v:false)

	" As this edit wasn't a diff operation, force diffupdate
	diffupdate
	call s:Workaround6_diffupdate()
	call s:StayOnDiff()
	if !empty(l:msg)
		call s:Message((curwinid == s:leftwinid ? s:lefttag : s:righttag) . l:msg)
	endif
	return v:true
endfunction

" Undo {{{1
" Undoes edits tracked by EasyDiff (see s:RecordEdit())
function! s:Undo() abort
	if !s:DiffStateValid()
		return v:false
	endif
	if empty(s:undo_stack)
		call s:Message('No tracked edit to undo')
		return v:false
	endif

	let l:leftmsg = ''
	let l:rightmsg = ''
	while v:true
		let entry = s:undo_stack[-1]
		let localwin = entry.winid == win_getid()
		let current_changenr = localwin ? changenr() : s:WinEval(entry.winid, 'changenr()')

		if entry.changenr != current_changenr
			" Proactive diffupdate preserves the next message. See
			" 'Implementation notes'
			diffupdate
			let l:warning = 'WED010: Manual edit or undo detected; Reset undo tracking'
			if entry.winid == s:leftwinid
				let l:leftmsg = s:lefttag . l:warning
			else
				let l:rightmsg = s:righttag . l:warning
			endif
			return s:ResetUndoTracking(l:leftmsg . l:rightmsg)
		endif

		if localwin
			let l:msg = trim(execute('silent undo'))
		else
			let l:msg = trim(win_execute(entry.winid, 'noautocmd silent undo'))
		endif
		if !empty(l:msg)
			if entry.winid == s:leftwinid
				let l:leftmsg = s:lefttag . l:msg
			else
				let l:rightmsg = s:righttag . l:msg
			endif
		endif

		call remove(s:undo_stack, -1)
		if !entry.grouped
			break
		endif
	endwhile

	diffupdate
	" Decide cursor position based on the last undo (entry.winid)
	call s:Workaround6_diffupdate(entry.winid)
	call s:StayOnDiff()
	call s:Message(l:leftmsg . l:rightmsg)
	return v:true
endfunction

" JumpToDiffStart {{{1
" Also helper for various functions
" Jump to the first line of the current Diff
" verbose(boolean): Whether to issue a helpful message
function! s:JumpToDiffStart(verbose) abort
	let curline = line('.')
	if !s:RepresentsChanged(curline)
		if a:verbose
			call s:Message('Not inside a Diff')
		endif
		return v:false
	endif
	" Uses [c or ]c to find the diff start. The alternative is to scan
	" backwards with diff_hlID(), which is O(hunk size).
	if curline < line('$')
		silent! normal! j[c
	else
		" curline is the last line of file and Diff. If curline is the
		" only line in Diff (so the desired start of Diff also), [c goes
		" to start of the the previous Diff, and subsequent ]c returns
		" to curline. If curline isn't the only line in this Diff, [c
		" goes to the start of this Diff and then the following ]c
		" silently fails. Finally if there is no previous Diff in file
		" before curline, [c silently fails, still staying at the
		" 'start' of this Diff. So in all cases we reach the start of
		" this Diff correctly.
		" NOTE: If curline represents multiple Diffs, say 'Changed' and
		" 'Filler after' ('EOF Filler'), then it is ambiguous as to
		" which Diff's start we should jump to. To be deterministic as a
		" Helper function, we remain at the 'EOF Filler's 'start'. This
		" also makes some sense when the Changed Diff is also of size 1.
		silent! normal! [c]c
	endif
	if a:verbose
		if curline == line('.')
			call s:Message('Already at Diff start')
		else
			echo ''
		endif
	endif
	return v:true
endfunction

" LastLineIsADifferentDiff {{{1
" Helper for s:JumpToDiffEnd
function! s:LastLineIsADifferentDiff() abort
	" We are already at the last line, and know that it is is Changed or
	" Added. But the last line may be preceded by a Filler, return v:true if
	" so.
	if diff_filler(line('.')) > 0
		return v:true
	endif

	" So it is adjacent with the previous line. Now if the last line had
	" flipped from Changed to Added or vice-versa, return v:true, else
	" v:false. To know that, we have to probe the other window's EOF Filler
	" lines.
	let otherwinid = win_getid(winnr() == 1 ? 2 : 1)
	let eof_fillers2 = s:WinEval(otherwinid, 'diff_filler(line("$")+1)')

	if eof_fillers2 == 0
		" last line in this window is Changed, and so the corresponding
		" line in other window as well. We can check if that line in
		" other window represents any fillers before, if it does, then
		" our last line had flipped from Added, else not.
		return s:WinEval(otherwinid, 'diff_filler(line(".")) > 0')
	endif
	" If eof_fillers2 == 1, last line flipped (it is the only Added
	" line and the previous was Changed); >1, it didn't flip (the previous
	" line was also Added).
	return eof_fillers2 == 1
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
		if s:LinematchEnabled()
			" Find lnum, the start of the next Diff
			noautocmd silent! normal! ]c
			let next = line('.')
			if next > origin && next <= curline
				if next == last
					" NOTE: last can represent multiple
					" Diffs - EOF Filler, this Diff's last
					" line or another one line Diff. Find if
					" last has broken ranks with the
					" previous lines (Changed to Added or
					" Added to Changed), and if it did, use
					" its preceding line as the end-of-Diff.
					let pos[1] = s:LastLineIsADifferentDiff() ? (last - 1) : last
				else
					let pos[1] = next - 1
				endif
			else
				let pos[1] = curline
			endif
		else
			" Without 'linematch' in diffopt, adjacent Added/Changed
			" sets are combined into a single Diff, so curline is
			" the end of Diff.
			let pos[1] = curline
		endif

		call setpos('.', pos)
		" See 'Implementation Notes' Workaround1.
		execute 'noautocmd silent normal! ' . (pos[1] == 1 ? 'jk' : 'kj')
	endif

	if a:verbose
		if pos[1] == origin
			call s:Message('Already at Diff end')
		else
			echo ''
		endif
	endif
	return v:true
endfunction

" JumpToFirstDiff {{{1
" Helper for s:HomeAction() and s:DiffModeSetup()
" Jump to the first line of the first Diff
" verbose(boolean): Whether to issue a helpful message
function! s:JumpToFirstDiff(verbose) abort
	let pos = getcurpos()
	let oldline = pos[1]
	" To go to the first line of the first Diff, we go to the first line,
	" next Diff, and then previous Diff. This accounts for the case where
	" the cursor is already inside the first Diff. silent! suppresses the
	" beep in vim
	silent! normal! gg]c[c
	let newline = line('.')
	if s:RepresentsDiff(newline)
		if a:verbose
			if newline == oldline
				call s:Message('Already at first Diff')
			else
				echo ''
			endif
		endif
	else
		if a:verbose
			call s:Message('No Diff present')
		endif
		if newline != oldline
			" Restore cursor
			call setpos(".", pos)
			" See 'Implementation Notes' Workaround1. Here
			" newline < oldline, so k is legal and kj succeeds.
			noautocmd silent normal! kj
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
	let oldline = pos[1]
	" To go to the first line of the last Diff, we go to the last line,
	" previous Diff, and then next Diff. This accounts for the case where
	" the cursor is already inside the last Diff. silent! suppresses the
	" beep in vim
	silent! normal! G[c]c
	let newline = line('.')
	if s:RepresentsDiff(newline)
		if a:verbose
			if newline == oldline
				call s:Message('Already at last Diff')
			else
				echo ''
			endif
		endif
	else
		if a:verbose
			call s:Message('No Diff present')
		endif
		if newline != oldline
			" Restore cursor
			call setpos(".", pos)
			" See 'Implementation Notes' Workaround1. Here
			" newline > oldline, so j is legal and jk succeeds.
			noautocmd silent normal! jk
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
	execute 'silent normal! ' . repeat . '[c'
	let newline = line('.')
	if newline == oldline
		if a:verbose
			call s:Message('No previous Diff to move to')
		endif
		if newline != pos[1]
			" Restore cursor
			call setpos(".", pos)
			" See 'Implementation Notes' Workaround1. Here
			" newline < oldline, so k is legal and kj succeeds.
			noautocmd silent normal! kj
		endif
		return v:false
	endif
	if a:verbose
		echo ''
	endif
	return v:true
endfunction

" JumpToNextDiff {{{1
" Jump to the first line of the next Diff
" verbose(boolean): Whether to issue a helpful message
function! s:JumpToNextDiff(verbose) abort
	let oldline = line('.')
	execute 'silent normal! ' . v:count1 . ']c'
	if oldline == line('.')
		if a:verbose
			call s:Message('No next Diff to move to')
		endif
		return v:false
	endif
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
		return s:DeleteDiffInBothWindows()
	endif
endfunction


" JumpToOtherWindow {{{1
" Helper for HomeAction()
function! s:JumpToOtherWindow() abort
	if !s:DiffStateValid()
		return v:false
	endif
	" Force exact line correspondence
	call s:Workaround6_diffupdate()
	noautocmd wincmd w
	call s:StayOnDiff()
	echo 'Changed focus to ' . (winnr() == 1 ? 'left' : 'right') . ' window'
	return v:true
endfunction

" HomeAction {{{1
" Overloaded <Home> with preceding count
function! s:HomeAction() abort
	if v:count1 == 1
		" v:count1 = 1 (no count) jumps to the first Diff
		return s:JumpToFirstDiff(v:true)
	else
		return s:JumpToOtherWindow()
	endif
endfunction

" EndAction {{{1
" Overloaded <End> with preceding count
function! s:EndAction() abort
	if v:count1 == 1
		" v:count1 = 1 (no count) moves cursor to the last Diff
		return s:JumpToLastDiff(v:true)
	endif
	if v:count1 == 2
		let g:easydiff_stay_on_diff = !g:easydiff_stay_on_diff
		echo 'g:easydiff_stay_on_diff ' . (g:easydiff_stay_on_diff ? 'enabled' : 'disabled')
	elseif v:count1 == 3
		" Toggle linematch in diffopt
		let linematch=matchstr(&diffopt, '\<linematch:\d\+\>')
		if empty(linematch)
			try
				if empty(s:saved_linematch)
					let s:saved_linematch='linematch:60'
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
	elseif v:count1 == 4
		" Toggle number
		if &number == 0
			let cmd='set number'
		else
			let cmd='set nonumber'
		endif
		for win in getwininfo()
			call win_execute(win.winid, 'noautocmd ' . cmd)
		endfor
		echo 'Executed "' . cmd . '" in both windows'
	endif

	return v:true
endfunction

" DiffModeSetup {{{1
" Sets up EasyDiff mappings in diff windows and jumps to start of first Diff.
function! s:DiffModeSetup() abort
	if !&diff || exists('w:diff_setup_done')
		return
	endif
	let w:diff_setup_done = 1

	" highlight for window tags ('right:' or 'left:') in messages
	highlight EasyDiffWindowTag cterm=bold ctermfg=Black ctermbg=Yellow gui=bold guifg=Black guibg=Yellow

	" A Non-zero scrolloff affects cursorbind which is vital to EasyDiff.
	" See 'Implementation Notes' Workaround7.
	setlocal scrolloff=0

	if empty(s:editor_version)
		if has('nvim')
			let s:editor_version = 'Neovim ' . matchstr(execute('version'), 'NVIM v\zs[^\n]*')
			if !has('nvim-0.11.6')
				call s:Message('WED008: EasyDiff untested on Neovim versions earlier than 0.11.6')
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
	endif

	nnoremap <buffer> <Right>    <Cmd>call <SID>MergeDiff(v:true)<CR>
	nnoremap <buffer> <Left>     <Cmd>call <SID>MergeDiff(v:false)<CR>
	nnoremap <buffer> <Del>      <Cmd>call <SID>DeleteAction()<CR>|	"Overloaded using count
	nmap     <buffer> <S-Del>    2<Del>|				"Convenient if terminal supports <S-Del>
	nnoremap <buffer> <BS>       <Cmd>call <SID>Undo()<CR>
	noremap  <buffer> <PageUp>   <Cmd>call <SID>JumpToDiffStart(v:true)<CR>
	noremap  <buffer> <PageDown> <Cmd>call <SID>JumpToDiffEnd(v:true)<CR>
	noremap  <buffer> <Home>     <Cmd>call <SID>HomeAction()<CR>|	"Overloaded using count
	map      <buffer> <S-Home>   2<Home>|				"Convenient if terminal supports <S-Home>
	noremap  <buffer> <End>      <Cmd>call <SID>EndAction()<CR>|	"Overloaded using count
	map      <buffer> <S-End>    2<End>|				"Convenient if terminal supports <S-End>
	noremap  <buffer> <Up>       <Cmd>call <SID>JumpToPreviousDiff(v:true)<CR>|	"Accepts count
	noremap  <buffer> <Down>     <Cmd>call <SID>JumpToNextDiff(v:true)<CR>|		"Accepts count
	nnoremap <buffer> <F1>       <Cmd>call <SID>ShowHelp()<CR>

	call s:JumpToFirstDiff(v:false)
endfunction

" DiffModeSetupInAllWindows {{{1
" Iterates over windows to invoke s:DiffModeSetup()
function! s:DiffModeSetupInAllWindows() abort
	for win in getwininfo()
		call win_execute(win.winid, 'noautocmd call <SID>DiffModeSetup()')
	endfor
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
augroup END
