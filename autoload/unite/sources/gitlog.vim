call unite#util#set_default(
      \ 'g:unite_source_gitlog_default_opts', '--graph --no-color --pretty=format:''%h -%d %s (%cr) <%an>'' --abbrev-commit --date=relative')
call unite#util#set_default('g:unite_source_gitlog_encoding', 'char')

function! unite#sources#gitlog#define()
  return s:source
endfunction

let s:source = {
      \ 'name': 'gitlog',
      \ 'max_candidates': 100,
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
      \    }
      \  }
      \ }

let s:is_windows = has('win16') || has('win32') || has('win64') || has('win95')


function! s:source.hooks.on_init(args, context) abort
  if !unite#util#has_vimproc()
    call unite#print_source_error(
          \ 'vimproc is not installed.', s:source.name)
    return
  endif

  if !exists('*fugitive#extract_git_dir')
    call unite#print_source_error('Could not detect fugitive.'
      \ . 'You should probably not working under a git repositry.'
      \ . 'Or not have fugitive installed', s:source.name)
    return
  endif

  let gitdir = fugitive#extract_git_dir(expand('%:p'))
  let a:context.source__directory = gitdir

  let extra = ''

  " first argument
  if get(a:args, 0, '') !=? 'all'
    let file = fnamemodify(expand('%:p'),
    \  ':s?'. fnamemodify(gitdir, ':h') . '/??')
    if s:is_windows | let file = substitute(file, '^\\', '', '') | endif
    let extra = extra . ' -- ' . file
  endif

  let days = get(a:args, 1, '')
  if len(days)
    let extra = extra . ' --since="' . days . 'days ago"'
  endif

  let a:context.source__bufname = bufname('%')
  let a:context.source__git_dir = gitdir
  let a:context.source__extra_opts = extra
endfunction

function! s:source.hooks.on_syntax(args, context)
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


function! s:source.hooks.on_close(args, context)
  if has_key(a:context, 'source__proc')
    call a:context.source__proc.kill()
  endif
endfunction

function! s:source.gather_candidates(args, context)
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


  "call unite#print_source_error(cmdline, self.name)

  call unite#add_source_message('Command-line: ' . cmdline, s:source.name)

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
          \ "v:val !~ '^\\s*$'")
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

function! s:getLineInfo(line)
  let ref = matchstr(a:line, '\v((\*\||)\s)@<=[0-9A-Za-z]{7}(\s-\s)@=')
  let user = matchstr(a:line, '\v\<[^<]+\>$')
  return [ref, user]
endfunction

function! s:source.action_table.delete.func(candidate)
  let ref = a:candidate.source__info[0]
  if !len(ref) | return | endif
  let gitdir = a:candidate.source__git_dir
  call s:diffWith(ref, a:candidate.source__bufname, gitdir)
endfunction

function! s:source.action_table.preview.func(candidate)
  let ref = a:candidate.source__info[0]
  let temp = a:candidate.source__tmp_file
  if !len(temp)
    let temp = fnamemodify(tempname(), ":h") . "/" . ref
    let cmd = ':silent ! git --git-dir=' . a:candidate.source__git_dir
          \. ' --no-pager show --no-color ' . ref . ' > ' . temp
    let a:candidate.source__tmp_file = temp
    execute cmd
  endif

  call unite#view#_preview_file(temp)
  call unite#add_previewed_buffer_list(temp)

  let winnr = winnr()
  execute 'wincmd P'
  let bufname = a:candidate.source__bufname
  let gitdir = a:candidate.source__git_dir
  execute 'nnoremap <buffer> d :<c-u>call <SID>diffWith("'.ref.'", "'.bufname. '","'.gitdir.'")<cr>'
  setlocal filetype=git buftype=nowrite readonly nomodified foldmethod=syntax
  setlocal foldtext=fugitive#foldtext()
  execute "normal! zM"
  execute winnr . 'wincmd w'
endfunction

function! s:source.action_table.open.func(candidate)
  let ref = a:candidate.source__info[0]
  if !len(ref) | return | endif
  exe "Gedit " . a:candidate.source__info[0]
endfunction

function! s:diffWith(ref, bufname, gitdir) abort
  let bnr = bufwinnr(a:bufname)
  execute bnr . 'wincmd w'

  let ftype = &filetype
  let prefix = system("git rev-parse --show-prefix")
  let base = substitute(a:gitdir, '\.git$', '', '')
  let gitfile = substitute(prefix,'\n$','','') . substitute(expand("%:p"), base, '', '')
  let tmpfile = tempname()
  let cmd = 'git --git-dir=' . a:gitdir
        \. ' --no-pager show --no-color ' . a:ref . ':' .gitfile . ' > ' . tmpfile

  let cmd_output = system(cmd)
  if v:shell_error && cmd_output != ""
    call unite#print_source_error(
          \ cmd_output, s:source.name)
    return
  endif

  " Begin diff
  exe "vert diffsplit " . tmpfile
  exe "set filetype=" . ftype
  set foldmethod=diff
  wincmd l

  let wnr = bufwinnr(tmpfile)
  execute wnr . 'wincmd w'
  execute "normal! zM"
  setlocal buftype=nowrite readonly nomodified foldmethod=diff
  if &bufhidden ==# ''
    setlocal bufhidden=delete
  endif
  execute "silent! file " . a:ref . ':' . gitfile
  if mapcheck("q", "n") == ""
    nnoremap <buffer> <silent> q  :<C-U>bdelete<CR>
  endif
  " used by fugitive
  call setbufvar(tmpfile, 'git_dir', a:gitdir)
  let w:fugitive_diff_restore = s:diff_restore()
endfunction

function! s:diff_restore() abort
  let restore = 'setlocal nodiff noscrollbind'
        \ . ' scrollopt=' . &l:scrollopt
        \ . (&l:wrap ? ' wrap' : ' nowrap')
        \ . ' foldlevel=999'
        \ . ' foldmethod=' . &l:foldmethod
        \ . ' foldcolumn=' . &l:foldcolumn
        \ . ' foldlevel=' . &l:foldlevel
        \ . (&l:foldenable ? ' foldenable' : ' nofoldenable')
  if has('cursorbind')
    let restore .= (&l:cursorbind ? ' ' : ' no') . 'cursorbind'
  endif
  return restore
endfunction
