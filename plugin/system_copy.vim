if exists('g:loaded_system_copy') || v:version < 700
  finish
endif
let g:loaded_system_copy = 1

if !exists("g:system_copy_silent")
  let g:system_copy_silent = 0
endif

let s:blockwise = 'blockwise visual'
let s:visual = 'visual'
let s:motion = 'motion'
let s:linewise = 'linewise'
let s:mac = 'mac'
let s:windows = 'windows'
let s:linux = 'linux'

function! s:system_copy(type, ...) abort
  let mode = <SID>resolve_mode(a:type, a:0)
  let unnamed = @@
  if mode == s:linewise
    let lines = { 'start': line("'["), 'end': line("']") }
    silent exe lines.start . "," . lines.end . "y"
  elseif mode == s:visual || mode == s:blockwise
    silent exe "normal! `<" . a:type . "`>y"
  else
    silent exe "normal! `[v`]y"
  endif
  let command = s:CopyCommandForCurrentOS()
  silent let command_output = system(command, getreg('@'))
  if v:shell_error != 0
    " Fall back to call OSC52 copy
    if exists("g:system_copy_enable_osc52") && g:system_copy_enable_osc52 > 0 && exists('*OSCYankString')
      call OSCYankString(getreg('@'))
    else
      echoerr command_output
    endif
  else
    if g:system_copy_silent == 0
      echohl String | echon 'Copied to clipboard using: ' . command | echohl None
    endif
  endif
  let @@ = unnamed
endfunction

function! s:system_paste(type, ...) abort
  let command = <SID>PasteCommandForCurrentOS()
  silent let command_output = system(command)
  if v:shell_error != 0
    echoerr command_output
  else
    let paste_content = command_output
    let mode = <SID>resolve_mode(a:type, a:0)
    let unnamed = @@
    silent exe "set paste"
    if mode == s:linewise
      let lines = { 'start': line("'["), 'end': line("']") }
      silent exe lines.start . "," . lines.end . "d"
      silent exe "normal! O" . paste_content
    elseif mode == s:visual || mode == s:blockwise
      silent exe "normal! `<" . a:type . "`>c" . paste_content
    else
      let str_len = strcharlen(paste_content)-1
			let multiline = strcharpart(paste_content, str_len, 1) == "\n"
			let c = [{'p': 'a', 'P': 'i'},{'p': 'o', 'P': 'O'}][multiline]
      silent exe "normal! " . c[a:type] . (multiline ? strcharpart(paste_content, 0, str_len) : paste_content)
    endif
    silent exe "set nopaste"
    if g:system_copy_silent == 0
      echohl String | echon 'Pasted to clipboard using: ' . command | echohl None
    endif
    let @@ = unnamed
  endif
endfunction

function! s:resolve_mode(type, arg)
  let visual_mode = a:arg != 0
  if visual_mode
    return (a:type == '') ?  s:blockwise : s:visual
  elseif a:type == 'line'
    return s:linewise
  else
    return s:motion
  endif
endfunction

function! s:currentOS()
  let os = substitute(system('uname'), '\n', '', '')
  let known_os = 'unknown'
  if has("gui_mac") || os ==? 'Darwin'
    let known_os = s:mac
  elseif has("win32") || os =~? 'cygwin' || os =~? 'MINGW'
    let known_os = s:windows
  elseif os ==? 'Linux'
    let known_os = s:linux
  else
    exe "normal \<Esc>"
    throw "unknown OS: " . os
  endif
  return known_os
endfunction

function! s:CopyCommandForCurrentOS()
  if exists('g:system_copy#copy_command')
    return g:system_copy#copy_command
  endif
  let os = <SID>currentOS()
  if os == s:mac
    return 'pbcopy'
  elseif os == s:windows
    return 'clip'
  elseif os == s:linux
    if !empty($WAYLAND_DISPLAY)
      return 'wl-copy'
    else
      return 'xsel --clipboard --input'
    endif
  endif
endfunction

function! s:PasteCommandForCurrentOS()
  if exists('g:system_copy#paste_command')
    return g:system_copy#paste_command
  endif
  let os = <SID>currentOS()
  if os == s:mac
    return 'pbpaste'
  elseif os == s:windows
    return 'paste'
  elseif os == s:linux
    if !empty($WAYLAND_DISPLAY)
      return 'wl-paste -n'
    else
      return 'xsel --clipboard --output'
    endif
  endif
endfunction

xnoremap <silent> <Plug>SystemCopy :<C-U>call <SID>system_copy(visualmode(),visualmode() ==# 'V' ? 1 : 0)<CR>
nnoremap <silent> <Plug>SystemCopy :<C-U>set opfunc=<SID>system_copy<CR>g@
nnoremap <silent> <Plug>SystemCopyLine :<C-U>set opfunc=<SID>system_copy<Bar>exe 'norm! 'v:count1.'g@_'<CR>
xnoremap <silent> <Plug>SystemPaste :<C-U>call <SID>system_paste(visualmode(),visualmode() ==# 'V' ? 1 : 0)<CR>
nnoremap <silent> <Plug>SystemPaste :<C-U>call <SID>system_paste('p')<CR>
nnoremap <silent> <Plug>SystemPasteLine :<C-U>call <SID>system_paste('P')<CR>
" vim:ts=2:sw=2:sts=2
