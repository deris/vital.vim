" TODO: move all comments to doc file.
"
"
" FIXME: This module name should be Vital.System ?
" But the name has been already taken.

let s:save_cpo = &cpo
set cpo&vim


" FIXME: Unfortunately, can't use s:_vital_loaded() for this purpose.
" Because these variables are used when this script file is loaded.
let s:is_windows = has('win16') || has('win32') || has('win64') || has('win95')
let s:is_unix = has('unix')
" As of 7.4.122, the system()'s 1st argument is converted internally by Vim.
" Note that Patch 7.4.122 does not convert system()'s 2nd argument and
" return-value. We must convert them manually.
let s:need_trans = v:version < 704 || (v:version == 704 && !has('patch122'))

let s:TYPE_DICT = type({})
let s:TYPE_LIST = type([])
let s:TYPE_STRING = type("")

function! s:spawn(expr, ...) abort
  let shellslash = 0
  if s:is_windows
    let shellslash = &l:shellslash
    setlocal noshellslash
  endif
  try
    if type(a:expr) is s:TYPE_LIST
      let special = 1
      let cmdline = join(map(a:expr, 'shellescape(v:val, special)'), ' ')
    elseif type(a:expr) is s:TYPE_STRING
      let cmdline = a:expr
      if a:0 && a:1
        " for :! command
        let cmdline = substitute(cmdline, '\([!%#]\|<[^<>]\+>\)', '\\\1', 'g')
      endif
    else
      throw 'Process.spawn(): invalid argument (value type:'.type(a:expr).')'
    endif
    if s:is_windows
      silent execute '!start' cmdline
    else
      silent execute '!' cmdline '&'
    endif
  finally
    if s:is_windows
      let &l:shellslash = shellslash
    endif
  endtry
  return ''
endfunction

" iconv() wrapper for safety.
function! s:iconv(expr, from, to) abort
  if a:from == '' || a:to == '' || a:from ==? a:to
    return a:expr
  endif
  let result = iconv(a:expr, a:from, a:to)
  return result != '' ? result : a:expr
endfunction

" Check vimproc.
function! s:has_vimproc() abort
  if !exists('s:exists_vimproc')
    try
      call vimproc#version()
      let s:exists_vimproc = 1
    catch
      let s:exists_vimproc = 0
    endtry
  endif
  return s:exists_vimproc
endfunction

" * {command} [, {input} [, {timeout}]]
" * {command} [, {dict}]
"   {dict} = {
"     use_vimproc: bool,
"     input: string,
"     timeout: bool,
"     background: bool,
"   }
function! s:system(str, ...) abort
  " Process optional arguments at first
  " because use_vimproc is required later
  " for a:str argument.
  let input = ''
  let use_vimproc = s:has_vimproc()
  let background = 0
  let args = []
  if a:0 ==# 1
    " {command} [, {dict}]
    " a:1 = {dict}
    if type(a:1) is s:TYPE_DICT
      if has_key(a:1, 'use_vimproc')
        let use_vimproc = a:1.use_vimproc
      endif
      if has_key(a:1, 'input')
        let args += [s:iconv(a:1.input, &encoding, 'char')]
      endif
      if use_vimproc && has_key(a:1, 'timeout')
        " ignores timeout unless you have vimproc.
        let args += [a:1.timeout]
      endif
      if has_key(a:1, 'background')
        let background = a:1.background
      endif
    elseif type(a:1) is s:TYPE_STRING
      let args += [s:iconv(a:1, &encoding, 'char')]
    else
      throw 'Process.system(): invalid argument (value type:'.type(a:1).')'
    endif
  elseif a:0 >= 2
    " {command} [, {input} [, {timeout}]]
    " a:000 = [{input} [, {timeout}]]
    let [input; rest] = a:000
    let input   = s:iconv(input, &encoding, 'char')
    let args += [input] + rest
  endif

  " Process a:str argument.
  if type(a:str) is s:TYPE_LIST
    let expr = use_vimproc ? '"''" . v:val . "''"' : 's:shellescape(v:val)'
    let command = join(map(copy(a:str), expr), ' ')
  elseif type(a:str) is s:TYPE_STRING
    let command = a:str
  else
    throw 'Process.system(): invalid argument (value type:'.type(a:str).')'
  endif
  if s:need_trans
    let command = s:iconv(command, &encoding, 'char')
  endif
  let args = [command] + args
  if background && (use_vimproc || !s:is_windows)
    let args[0] = args[0] . ' &'
  endif

  let funcname = use_vimproc ? 'vimproc#system' : 'system'
  let output = call(funcname, args)
  let output = s:iconv(output, 'char', &encoding)
  return output
endfunction

function! s:get_last_status() abort
  return s:has_vimproc() ?
        \ vimproc#get_last_status() : v:shell_error
endfunction

if s:is_windows
  function! s:shellescape(command) abort
    return substitute(a:command, '[&()[\]{}^=;!''+,`~]', '^\0', 'g')
  endfunction
else
  function! s:shellescape(...) abort
    return call('shellescape', a:000)
  endfunction
endif


let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:
