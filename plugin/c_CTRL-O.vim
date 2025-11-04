if exists('g:loaded_c_ctrl_o')
  finish
endif
let g:loaded_c_ctrl_o = 1

let s:cpo_save = &cpo
set cpo&vim

" I can think of two ways of making a |c_CTRL-O|:
"  1. exit command-line mode, execute one normal-mode command by entering
"     insert mode, feeding a <c-o> and waiting for |InsertEnter|, resume
"     command-line mode, and rebuild incsearch state (`incsearch_state_T
"     is_state;` in `getcmdline()` in ex_getln.c); or
"  2. stay in command-line mode, write a makeshift input parser that reads in
"     one normal-mode command, and execute it using |:normal|.
" attempting to rebuild incsearch state sounds tricky and bug prone, so
" we opt for option 2. the expression register is evaluated under |textlock|
" (see `cmdline_paste()` in ex_getln.c for |c_CTRL-R| and
" `cmdline_handle_ctrl_bsl()` in ex_getln.c for |c_CTRL-\_e|), but |<cmd>|
" isn't, so that's what we run :normal with.

" here are the bits of Vim relevant to our makeshift input parsing, located
" in normal.c unless noted otherwise:
"   - `nv_cmds[]` in nv_cmds.h
"   - `normal_cmd()`, `normal_cmd_get_count()`,
"     `normal_cmd_needs_more_chars()`, `normal_cmd_get_more_chars()`
"   - `nv_zet()`, `nv_Zet()`, `nv_z_get_count`, `nv_g_cmd()`, `nv_at()`,
"     `nv_regname()`, `nv_operator()`
" see also |normal-index|, including all subsections right up until (and
" excluding) |visual-index|

function! s:getcount()
  let l:cmd = getcharstr()
  while l:cmd =~ "\\v[1-9](\\d|\<del>)*$" | let l:cmd .= getcharstr() | endw
  return l:cmd
endfunction

function! s:getreg()
  let l:cmd = getcharstr()
  if l:cmd =~ '=$' | return l:cmd.input('=')."\<cr>" | endif
  return l:cmd
endfunction

function! s:getcmd(operator_pending)
  let l:cmd = s:getcount()
  if l:cmd =~# "[][fFtT'`\<c-\>]$" | return l:cmd.getcharstr() | endif
  if l:cmd =~ '[:/?]$' | return l:cmd.input(l:cmd[-1:])."\<cr>" | endif
  if a:operator_pending
    if l:cmd =~# "[vV\<c-v>]$" | return l:cmd.s:getcmd(1) | endif
    if l:cmd =~# '[aiz]$' | return l:cmd.getcharstr() | endif
    if l:cmd =~# 'g$' | let l:cmd .= getcharstr()
      if l:cmd =~ "['`]$" | return l:cmd.getcharstr() | endif
      return l:cmd
    endif
    return l:cmd
  else
    if l:cmd =~ '!$' | return l:cmd.s:getcmd(1).input(':!')."\<cr>" | endif
    if l:cmd =~ "\<c-w>$" | let l:cmd .= s:getcount()
      if l:cmd =~# 'g$' | return l:cmd.getcharstr() | endif
      return l:cmd
    endif
    if l:cmd =~ '@$' | return l:cmd.s:getreg() | endif
    if l:cmd =~ '"$' | return l:cmd.s:getreg().s:getcmd(0) | endif
    if l:cmd =~# '[mZr]$' | return l:cmd.getcharstr() | endif
    if l:cmd =~# '[<=>cdy]$' | return l:cmd.s:getcmd(1) | endif
    " nv_z_get_count() can actually parse a count of 0 but let's not bother
    if l:cmd =~# "z$" | let l:cmd .= s:getcount()
      if l:cmd =~# 'u$' | return l:cmd.getcharstr() | endif
      if l:cmd =~# '[yf]$' | return l:cmd.s:getcmd(1) | endif
      return l:cmd
    endif
    if l:cmd =~# "g$" | let l:cmd .= getcharstr()
      if l:cmd =~# "[qw~uU?@]$" | return l:cmd.s:getcmd(1) | endif
      if l:cmd =~# "['`r]$" | return l:cmd.getcharstr() | endif
      return l:cmd
    endif
    return l:cmd
  endif
  throw 'unreachable'
endfunction

" have to use a |<plug>| mapping instead of a :function because functions
" preserve the last search pattern, see |function-search-undo|, which breaks
" the highlighting for <c-o>/...<cr>
cnoremap <plug>CCtrlOGo <cmd>echohl ModeMsg
      \ <bar>echo &showmode ? '-- (command-line) --' : ''<bar>echohl None
      "\ have to start a new undo block, otherwise say <c-o>dd<c-o>dd<c-o>u
      "\ undoes both changes; using :silent! in case 'nomodifiable' is set
      \ <bar>execute 'silent! normal! i<c-g>u<right><c-c>'
      "\ using :normal without ! so mappings are resolved (this is optimistic:
      "\ the mappings have to be "Vim-like" for s:getcmd() to work). using ""
      "\ as a no-op so <c-o><space> and <c-o><tab> work, see |:normal|
      \ <bar>execute 'normal ""'.<sid>getcmd(0)
      "\ have to call :redraw from the expression register instead of calling
      "\ it directly, otherwise scrolling using say <c-o><c-d> flickers but
      "\ doesn't scroll.
      \ <bar>call feedkeys("<c-r>=execute('redraw')[-1]\n", 'ni')

cnoremap <plug>CCtrlOOneShot <plug>CCtrlOGo<cr>
" using <bs> because the |line-continuation| adds a trailing space. also,
" note that <c-c> (and <esc> and <c-\><c-n> for that matter) actually goes
" to insert mode when the command-line was invoked from |i_CTRL-O|, and we
" want to preserve that behavior
cnoremap <plug>CCtrlOAbandon <cmd>let w:view = winsaveview()<cr>
      \ <bs><c-c><cmd>normal! m'<cr><cmd>call winrestview(w:view)<cr>
" with <plug>CCtrlOOneShot working, these two are freebies
cnoremap <plug>CCtrlOInsert <plug>CCtrlOGo
      \ <bar>call feedkeys('<c-r>"', 'ni')<cr>y
cnoremap <plug>CCtrlOInsLit <plug>CCtrlOGo
      \ <bar>call feedkeys('<c-r><c-r>"', 'ni')<cr>y

if !exists('g:c_ctrl_o_no_mappings') || !g:c_ctrl_o_no_mappings
  cnoremap <c-o>           <plug>CCtrlOOneShot
  cnoremap <c-\><c-o>      <plug>CCtrlOAbandon
  cnoremap <c-r><c-o>      <plug>CCtrlOInsert
  cnoremap <c-r><c-r><c-o> <plug>CCtrlOInsLit
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:tw=78:
