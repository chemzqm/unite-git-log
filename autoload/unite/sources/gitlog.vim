call unite#util#set_default(
      \ 'g:unite_source_gitlog_default_opts', '--graph --no-color --pretty=format:''%h -%d %s (%cr) <%an>'' --abbrev-commit --date=relative')
call unite#util#set_default('g:unite_source_gitlog_encoding', 'char')

function! unite#sources#gitlog#define()
  return s:source
endfunction

let s:preview_bufnr = 0

let s:source = {
      \ 'name': 'gitlog',
      \ 'max_candidates': 500,
      \ 'description': 'candidates form gitlog',
      \ 'hooks' : {},
      \ 'syntax' : 'uniteSource__Gitlog',
      \ "default_action" : "open",
      \ 'action_table' : {
      \    'open' : {
      \      'description' : 'open commit detail',
      \      'is_selectable' : 0,
      \    },
      \    'delete': {
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
      \      'description': 'git reset commit',
      \      'is_quit': 0,
      \      'is_selectable': 0,
      \    },
      \  }
      \}

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

  if &buftype == 'nofile'
    let gitdir = s:FindGitdir()
  else
    let gitdir = easygit#gitdir(expand('%'), 1)
  endif

  let a:context.source__directory = gitdir

  let extra = empty(get(a:args, 1, '')) ? '' :
    \ ' --since="' . a:args[1] . 'days ago"'

  " first argument
  if get(a:args, 0, '') !=? 'all'
    let file = fnamemodify(expand('%:p'),
    \  ':s?'. fnamemodify(gitdir, ':h') . '/??')
    if s:is_windows | let file = substitute(file, '^\\', '', '') | endif
    let extra = extra . ' -- ' . shellescape(file)
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

  syntax match uniteSource__GitlogRef /\v((\*\||)\s)@<=[0-9A-Za-z]{7,13}(\s-\s)@=/ contained
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
  if !exists('a:context.source__git_dir')
    let a:context.is_async = 0
    return []
  endif

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
          \ 'source__bufname' : a:context.source__bufname,
          \ 'source__info' : info,
          \ "kind": ["file", "command"],
          \ })
  endfor

  return candidates
endfunction

function! s:getLineInfo(line) abort
  let ref = matchstr(a:line, '\v((\*\||)\s)@<=[0-9A-Za-z]{7,13}(\s-\s)@=')
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
  if s:preview_bufnr && bufexists(s:preview_bufnr)
    execute 'bunload! '.s:preview_bufnr
  endif
  call easygit#show(ref, {
        \ 'all': 1,
        \ 'gitdir': a:candidate.source__git_dir,
        \ 'edit': 'vsplit',
        \})
  let s:preview_bufnr = bufnr('%')
  wincmd p
endfunction

" Rewrite show d to show diff, q to quite
function! s:source.action_table.open.func(candidate) abort
  let ref = a:candidate.source__info[0]
  let bufname = a:candidate.source__bufname
  let wnr = bufwinnr(bufname)

  if wnr > 0
    exe wnr . 'wincmd w'
  endif

  call easygit#show(ref, {
        \ 'all': 1,
        \ 'gitdir': a:candidate.source__git_dir,
        \})
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
  let m = input('select reset mode mixed|soft|hard [m/s/h]')
  if empty(m) || m =~? 'c'
    return
  elseif m =~? 'm'
    let opt = '--mixed '
  elseif m =~? 's'
    let opt = '--soft '
  endif
  let output = system('git reset ' . opt . ref)
  if v:shell_error && output !=# ""
    echohl Error | echon output | echohl None
    exe 'lcd ' . cwd
    return
  endif
  exe 'silent edit'
  exe 'lcd ' . cwd
  execute 'wincmd p'
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

function! s:FindGitdir()
  let dir = finddir('.git', expand(getcwd() . ';'))
  if empty(dir) | return '' | endif
  return fnamemodify(dir, ':p:h')
endfunction
