if exists('g:loaded_c_ctrl_o')
  finish
endif
let g:loaded_c_ctrl_o = 1

let s:cpo_save = &cpo
set cpo&vim

" we can't exit the command-line because that would discard the state for
" incremental search (`incsearch_state_T is_state;` is a local variable of
" `getcmdline()` in ex_getln.c, which gets called from `nv_search()` in
" normal.c, the implementation of |?| and |/|). so I can't think of anything
" better than makeshift input parsing then calling |:normal| from the
" expression register. though |:normal| can't record macros, and |c_CTRL-R|
" and |c_CTRL-\_e| enable |textlock| (see `cmdline_paste()` in ex_getln.c for
" |c_CTRL-R| and `cmdline_handle_ctrl_bsl()` in ex_getln.c for |c_CTRL-\_e|).
" on one hand this severely nerfs this plugin, but on the other it means that
" most commands we don't actually need to parse

" here are the bits of Vim relevant to our makeshift input parsing, located
" in normal.c unless noted otherwise:
"   - `nv_cmds[]` in nv_cmds.h
"   - `normal_cmd()`, `normal_cmd_get_count()`,
"     `normal_cmd_needs_more_chars()`, `normal_cmd_get_more_chars()`
"   - `nv_zet()`, `nv_z_get_count`, `nv_g_cmd()`, `nv_at()`,
"     `nv_regname()`, `nv_operator()`
" see also |normal-index|, including all subsections right up until (and
" excluding) |visual-index|

function! s:showmode(showmode)
  echohl ModeMsg | echo &showmode ? '-- (command-line) --' : '' | echohl None
endfunction

function! s:getcmd(operator_pending)
  let l:cmd = s:getcount()
  if a:operator_pending
    if l:cmd =~# "[vV\<c-v>]$" | return l:cmd.s:getcmd(1) | endif
    if l:cmd =~# '[ai]$' | return l:cmd.getcharstr() | endif
    if l:cmd =~# "z$" | return l:cmd.getcharstr() | endif
  else
    if l:cmd =~ "\<c-w>$" | return l:cmd.s:getcount() | endif
    if l:cmd =~ '@$' | return l:cmd.s:getreg() | endif
    if l:cmd =~ '"$' | return l:cmd.s:getreg().s:getcmd(0) | endif
    if l:cmd =~# 'm$' | return l:cmd.getcharstr() | endif
    if l:cmd =~# 'y$' | return l:cmd.s:getcmd(1) | endif
    if l:cmd =~# "z$" | let l:cmd .= s:getcount()
      if l:cmd =~# 'u$' | return l:cmd.getcharstr() | endif
      if l:cmd =~# '[yf]$' | return l:cmd.s:getcmd(1) | endif
      return l:cmd
    endif
  endif
  if l:cmd =~# "[][gfFtT'`\<c-\>]$" | let l:cmd .= getcharstr()
    if l:cmd =~# "g['`]$" | return l:cmd.getcharstr() | endif
    return l:cmd
  endif
  if l:cmd =~ '[:/?]$' | let l:cmd .= input(l:cmd[-1:])."\<cr>" | endif
  return l:cmd
endfunction

function! s:getreg()
  let l:cmd = getcharstr()
  if l:cmd =~ '=$' | let l:cmd .= input(l:cmd[-1:])."\<cr>" | endif
  call s:showmode() " for "=123<cr>yy
  return l:cmd
endfunction

function! s:getcount()
  let l:cmd = getcharstr()
  while l:cmd =~ "\\v[1-9](\\d|\<del>)*$" | let l:cmd .= getcharstr() | endw
  return l:cmd
endfunction

" using 'silent!' to avoid delay on error, say with :<c-o>x<c-o><c-e>. using
" :normal without ! so mappings are resolved (this is optimistic: the mappings
" have to be "Vim-like" for s:getcmd() to work). using y<c-v><esc> as a no-op
" so the |<space>| and |<tab>| command work; see |:normal|
cnoremap <plug>CCtrlOOneShot <c-r>=<sid>showmode()[-1].execute([
      \   'normal y<c-v><esc>'.<sid>getcmd(0), 'redraw'
      \ ], 'silent!')[-1]<cr>
" note that <c-c> (and <esc> and <c-\><c-n> for that matter) actually goes to
" insert mode when the command-line was invoked from |i_CTRL-O|, and we want
" to preserve that behavior
cnoremap <plug>CCtrlOAbandon <cmd>let w:view = winsaveview()<cr>
      \ <c-c><cmd>normal! m'<cr><cmd>call winrestview(w:view)<cr>

" with <plug>CCtrlOOneShot working, these two mappings are freebies
cnoremap <plug>CCtrlOInsert <c-r>=<sid>showmode()[-1].execute([
      \   'let @"=""', 'normal y'.<sid>getcmd(1), 'redraw'
      \ ], 'silent!')[-1].@"<cr>
cnoremap <plug>CCtrlOInsLit <c-r><c-r>=<sid>showmode()[-1].execute([
      \   'let @"=""', 'normal y'.<sid>getcmd(1), 'redraw'
      \ ], 'silent!')[-1].@"<cr>

if !exists('g:c_ctrl_o_no_mappings') || !g:c_ctrl_o_no_mappings
  cnoremap <c-o>           <plug>CCtrlOOneShot
  cnoremap <c-\><c-o>      <plug>CCtrlOAbandon
  cnoremap <c-r><c-o>      <plug>CCtrlOInsert
  cnoremap <c-r><c-r><c-o> <plug>CCtrlOInsLit
endif

let &cpo = s:cpo_save
unlet s:cpo_save
