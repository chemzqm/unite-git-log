call unite#util#set_default(
      \ 'g:unite_source_gitlog_default_opts', '--graph --no-color --pretty=format:''%h -%d %s (%cr) <%an>'' --abbrev-commit --date=relative')
call unite#util#set_default('g:unite_source_gitlog_encoding', 'char')

function! unite#sources#gitlog#define()
  return s:source
endfunction

let s:source = {
      \ 'name': 'gitlog',
      \ 'max_candidates': 500,
      \ 'hooks' : {},
      \ 'syntax' : 'uniteSource__Gitlog',
      \  "default_action" : "open",
      \  'action_table' : {
      \    'open' : {
      \      'description' : 'open commit detail',
      \      'is_selectable' : 0,
      \    },
      \   'delete': {
      \      'description': 'git diff of current file',
      \      'is_selectable': 0,
      \      'is_quit': 0,
      \    },
      \    'preview': {
      \      'description': 'preview git log',
      \      'is_quit': 0,
      \      'is_selectable': 0,
      \    },
      \    'reset': {
      \      'description': 'reset --hard',
      \      'is_quit': 0,
      \      'is_selectable': 0,
      \    },
      \  }
      \ }

let s:is_windows = has('win16') || has('win32') || has('win64') || has('win95')

function! s:source.hooks.on_init(args, context) abort
  if !unite#util#has_vimproc()
    call unite#print_source_error(
          \ 'vimproc is not installed.', s:source.name)
    return
  endif

  if !exists('g:did_easygit_loaded')
    call unite#print_source_error('Could not detect easygit.'
      \ . 'You need to install it from '
      \ . 'https://github.com/chemzqm/vim-easygit first', s:source.name)
    return
  endif

  let gitdir = easygit#gitdir(expand('%'))
  let a:context.source__directory = gitdir

  let extra = empty(get(a:args, 1, '')) ? '' :
    \ ' --since="' . a:args[1] . 'days ago"'

  " first argument
  if get(a:args, 0, '') !=? 'all'
    let file = fnamemodify(expand('%:p'),
    \  ':s?'. fnamemodify(gitdir, ':h') . '/??')
    if s:is_windows | let file = substitute(file, '^\\', '', '') | endif
    let extra = extra . ' -- ' . file
  endif

  let a:context.source__bufname = bufname('%')
  let a:context.source__git_dir = gitdir
  let a:context.source__extra_opts = extra
endfunction

function! s:source.hooks.on_syntax(args, context) abort
  if !unite#util#has_vimproc()
    return
  endif

  syntax case ignore
  syntax match uniteSource__GitlogHeader /^.*$/
        \ containedin=uniteSource__Gitlog
  syntax match uniteSource__GitlogRef /\v((\*\||)\s)@<=[0-9A-Za-z]{7}(\s-\s)@=/ contained
        \ containedin=uniteSource__GitlogHeader
        \ nextgroup=uniteSource__GitlogTag,uniteSource__GitlogTime
  syntax match uniteSource__GitlogTag /(.\{-}tag:\s.\{-})/ contained
        \ containedin=uniteSource__GitlogHeader
        \ nextgroup=uniteSource__GitlogTime
  syntax match uniteSource__GitlogTime /(\(\w\|\s\)\{-}\sago)/ contained
        \ containedin=uniteSource__GitlogHeader
        \ nextgroup=uniteSource__GitlogUser
  syntax match uniteSource__GitlogUser /\v\<[^<]+\>$/ contained
        \ containedin=uniteSource__GitlogHeader

  highlight default link uniteSource__GitlogRef Title
  highlight default link uniteSource__GitlogTag Type
  highlight default link uniteSource__GitlogTime Keyword
  highlight default link uniteSource__GitlogUser Constant

endfunction

function! s:source.hooks.on_close(args, context) abort
  if has_key(a:context, 'source__proc')
    call a:context.source__proc.kill()
  endif
endfunction

function! s:source.gather_candidates(args, context) abort
  let command = 'git --git-dir=' . a:context.source__git_dir
        \. ' --no-pager log'

  let default_opts = get(a:context, 'custom_gitlog_default_opts',
        \ g:unite_source_gitlog_default_opts)

  if !unite#util#has_vimproc()
    call unite#print_source_error(
          \ 'vimproc plugin is not installed.', self.name)
    let a:context.is_async = 0
    return []
  endif

  if a:context.is_redraw
    let a:context.is_async = 1
  endif

  let cmdline = printf('%s %s %s',
    \   command,
    \   default_opts,
    \   a:context.source__extra_opts,
    \)

  let save_term = $TERM
  try
    " Disable colors.
    let $TERM = 'dumb'
    let a:context.source__proc = vimproc#plineopen3(
          \ vimproc#util#iconv(cmdline, &encoding,
          \ g:unite_source_gitlog_encoding),
          \ unite#helper#is_pty(command))
  finally
    let $TERM = save_term
  endtry

  return self.async_gather_candidates(a:args, a:context)
endfunction

function! s:source.async_gather_candidates(args, context) abort
  let default_opts = get(a:context, 'custom_gitlog_default_opts',
        \ g:unite_source_gitlog_default_opts)

  if !has_key(a:context, 'source__proc')
    let a:context.is_async = 0
    return []
  endif

  let stderr = a:context.source__proc.stderr
  if !stderr.eof
    " Print error.
    let errors = filter(unite#util#read_lines(stderr, 200),
          \ "v:val !~? '^\\s*$'")
    if !empty(errors)
      call unite#print_source_error(errors, s:source.name)
    endif
  endif

  let stdout = a:context.source__proc.stdout
  if stdout.eof
    " Disable async.
    let a:context.is_async = 0
    call a:context.source__proc.waitpid()
  endif

  let lines = map(unite#util#read_lines(stdout, 1000),
          \ "unite#util#iconv(v:val, g:unite_source_gitlog_encoding, &encoding)")

  let candidates = []
  for line in lines
    let info = s:getLineInfo(line)
    let is_dummy = len(info[0]) ? 0 : 1
    call add(candidates, {
          \ 'word' : line,
          \ 'is_dummy' : is_dummy,
          \ 'source__git_dir' : a:context.source__git_dir,
          \ 'source__tmp_file': '',
          \ 'source__bufname' : a:context.source__bufname,
          \ 'source__info' : info,
          \ "kind": ["file", "command"],
          \ })
  endfor

  return candidates
endfunction

function! s:getLineInfo(line) abort
  let ref = matchstr(a:line, '\v((\*\||)\s)@<=[0-9A-Za-z]{7}(\s-\s)@=')
  let user = matchstr(a:line, '\v\<[^<]+\>$')
  return [ref, user]
endfunction

function! s:source.action_table.delete.func(candidate) abort
  let ref = a:candidate.source__info[0]
  if !len(ref) | return | endif
  let gitdir = a:candidate.source__git_dir
  call s:diffWith(ref, a:candidate.source__bufname)
endfunction

function! s:source.action_table.preview.func(candidate) abort
  let ref = a:candidate.source__info[0]
  let temp = a:candidate.source__tmp_file
  if !empty(temp)
    let temp = fnamemodify(tempname(), ":h") . "/" . ref
    let cmd = ':silent ! git --git-dir=' . a:candidate.source__git_dir
          \. ' --no-pager show --no-color ' . ref . ' > ' . temp . ' 2>&1'
    let a:candidate.source__tmp_file = temp
    execute cmd
  endif

  call unite#view#_preview_file(temp)
  call unite#add_previewed_buffer_list(temp)

  let winnr = winnr()
  execute 'wincmd P'
  let bufname = a:candidate.source__bufname
  let gitdir = a:candidate.source__git_dir
  execute 'nnoremap <silent> <buffer> d :<c-u>call <SID>diffWith("'.ref.'", "'.bufname. '")<cr>'
  setlocal filetype=git buftype=nofile readonly foldmethod=syntax
  setlocal foldtext=easygit#foldtext()
  execute winnr . 'wincmd w'
endfunction

" Rewrite show d to show diff, q to quite
function! s:source.action_table.open.func(candidate) abort
  let ref = a:candidate.source__info[0]
  let temp = a:candidate.source__tmp_file
  let bufname = a:candidate.source__bufname
  let gitdir = a:candidate.source__git_dir
  let wnr = bufwinnr(bufname)
  if empty(temp)
    let temp = fnamemodify(tempname(), ":h") . "/" . ref
    let cmd = ':silent ! git --git-dir=' . a:candidate.source__git_dir
          \. ' --no-pager show --no-color ' . ref . ' > ' . temp . ' 2>&1'
    let a:candidate.source__tmp_file = temp
    execute cmd
  endif
  if wnr > 0
    exe wnr . 'wincmd w'
    execute 'edit ' . temp
  else
    let view = winsaveview()
    execute 'keepalt edit ' . temp
    call winrestview(view)
  endif

  execute 'nnoremap <silent> <buffer> d :<c-u>call'
        \.' <SID>diffWith("'.ref.'", "'.bufname. '")<cr>'
  execute 'nnoremap <silent> <buffer> q :<c-u>call '
        \.'<SID>smartQuite("'.bufname. '")<cr>'
  setlocal filetype=git buftype=nofile readonly foldmethod=syntax
  setlocal foldtext=easygit#foldtext()
endfunction

function! s:source.action_table.reset.func(candidate) abort
  let ref = a:candidate.source__info[0]
  let wnr = winnr()
  if empty(ref) | return | endif
  let bufname = a:candidate.source__bufname
  let wnr = bufwinnr(bufname)
  if wnr < 0 | return | endif
  execute wnr . 'wincmd w'
  let root = easygit#smartRoot()
  if empty(root) | return | endif
  let cwd = getcwd()
  exe 'lcd ' . root
  let output = system('git reset --hard ' . ref)
  if v:shell_error && output !=# ""
    echohl Error | echon output | echohl None
    exe 'lcd ' . cwd
    return
  endif
  exe 'lcd ' . cwd
  execute 'wincmd p'
  let unite = unite#get_current_unite()
  call unite#force_redraw()
endfunction

function! s:diffWith(ref, bufname) abort
  let wnr = bufwinnr(a:bufname)
  if wnr > 0
    execute wnr . 'wincmd w'
  else
    let nr = bufnr(a:bufname)
    exe 'keepalt b ' . nr
  endif
  call easygit#diffThis(a:ref)
endfunction

function! s:smartQuite(bufname)
  let nr = bufnr(a:bufname)
  exe 'keepalt b ' . nr
endfunction
