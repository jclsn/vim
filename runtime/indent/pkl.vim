" Copyright © 2026 Apple Inc. and the Pkl project authors. All rights reserved.
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"   https://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.

" Vim indent file
" Language:		Pkl
"
" Indents the contents of objects, classes, lists, argument lists and
" continuation lines after '=' and '->', like the tree-sitter indent queries
" of Neovim. The contents of multiline strings and block comments are left
" alone, since their indentation is part of the text.

if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

setlocal autoindent nosmartindent nocindent
setlocal indentexpr=GetPklIndent(v:lnum)
setlocal indentkeys=0{,0},0),0],0=else,0=\|,!^F,o,O

let b:undo_indent = 'setl ai< si< cin< inde< indk<'

if exists('*GetPklIndent')
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Syntax groups whose contents are text, not code
let s:text_groups = 'String\|Comment\|Escape\|Unicode'

function s:IsText(lnum, col) abort
  return synIDattr(synID(a:lnum, a:col, 1), 'name') =~# s:text_groups
endfunction

" Whether the line starts inside a multiline string or block comment
function s:StartsInRegion(lnum) abort
  let col = max([1, match(getline(a:lnum), '\S') + 1])
  for id in synstack(a:lnum, col)
    if synIDattr(id, 'name') =~# 'MultiString\|MultiComment'
      return 1
    endif
  endfor
  return 0
endfunction

" The line where the multiline string or block comment started, that
" contains the given line
function s:RegionStart(lnum) abort
  let lnum = a:lnum
  while lnum > 1 && s:StartsInRegion(lnum)
    let lnum = prevnonblank(lnum - 1)
  endwhile
  return lnum
endfunction

" Skip expression for searchpair(): ignore brackets in strings and comments
let s:skip = 's:IsText(line("."), col("."))'

" The line of the bracket that is closed at the given position
function s:OpeningLine(lnum, col) abort
  let save = getcurpos()
  call cursor(a:lnum, a:col)
  let char = getline(a:lnum)[a:col - 1]
  let pair = {')': '(', ']': '\[', '}': '{'}[char]
  let [lnum, _] = searchpairpos(pair, '', escape(char, ']'), 'bnW', s:skip)
  call setpos('.', save)
  return lnum
endfunction

" Returns the number of brackets that are opened on the line and not closed,
" and the column of the last bracket that closes one of a previous line.
function s:Brackets(lnum) abort
  let line = getline(a:lnum)
  let open = 0
  let last_close = 0
  let col = match(line, '[[\](){}]')
  while col >= 0
    if !s:IsText(a:lnum, col + 1)
      if line[col] =~# '[[({]'
        let open += 1
      elseif open > 0
        let open -= 1
      else
        let last_close = col + 1
      endif
    endif
    let col = match(line, '[[\](){}]', col + 1)
  endwhile
  return [open, last_close]
endfunction

" The last character of the line that isn't part of a comment
function s:LastCode(lnum) abort
  let line = getline(a:lnum)
  let col = len(line)
  while col > 0 && (line[col - 1] =~# '\s' || synIDattr(synID(a:lnum, col, 1), 'name') =~# 'Comment')
    let col -= 1
  endwhile
  return strpart(line, 0, col)
endfunction

" Whether the expression continues on the next line
function s:Continues(lnum) abort
  return s:LastCode(a:lnum) =~# '\%(=\|->\)$' && !s:IsText(a:lnum, len(s:LastCode(a:lnum)))
endfunction

" Whether the line continues the expression of the line before, e.g. a value
" after a trailing '=' or a member of a union type starting with '|'
function s:IsContinuation(lnum) abort
  let prev = prevnonblank(a:lnum - 1)
  return prev > 0 && (getline(a:lnum) =~# '^\s*|' || s:Continues(prev))
endfunction

" The first line of the expression the given line belongs to
function s:ExpressionStart(lnum) abort
  let lnum = a:lnum
  while lnum > 1 && s:IsContinuation(lnum)
    let lnum = s:RegionStart(prevnonblank(lnum - 1))
  endwhile
  return lnum
endfunction

function GetPklIndent(lnum) abort
  let prev = prevnonblank(a:lnum - 1)
  if prev == 0
    return 0
  endif
  let line = getline(a:lnum)

  " Text in multiline strings and block comments keeps its indentation. The
  " first line of a string is indented, when it is typed.
  if s:StartsInRegion(a:lnum)
    if line =~# '^\s*$' && !s:StartsInRegion(prev) && getline(prev) =~# '"""#*$'
      return indent(prev) + shiftwidth()
    endif
    return -1
  endif

  " A closing bracket is aligned with the line of the opening bracket
  let col = matchend(line, '^\s*[\])}]')
  if col > 0
    let lnum = s:OpeningLine(a:lnum, col)
    return lnum > 0 ? indent(s:RegionStart(lnum)) : indent(prev)
  endif

  " 'else' is aligned with its 'if'
  if line =~# '^\s*else\>'
    let lnum = search('\<if\s*(', 'bnW')
    return lnum > 0 ? indent(s:ExpressionStart(lnum)) : indent(prev)
  endif

  let [open, last_close] = s:Brackets(prev)
  if last_close > 0
    " The previous line closes a bracket of a line before, e.g. the last
    " argument of a call that spans multiple lines
    let lnum = s:OpeningLine(prev, last_close)
    let ind = lnum > 0 ? indent(s:ExpressionStart(s:RegionStart(lnum))) : indent(prev)
  elseif s:IsContinuation(prev) && !s:Continues(prev) && open == 0 && line !~# '^\s*|'
    " The previous line ends an expression that started on a line before
    let ind = indent(s:ExpressionStart(s:RegionStart(prev)))
  else
    let ind = indent(s:RegionStart(prev))
  endif

  if open > 0 || s:Continues(prev) || getline(prev) =~# '^\s*\%(}\s*\)\=else\s*$'
        \ || s:LastCode(prev) =~# '\<if\s*(.*)$'
    let ind += shiftwidth()
  endif
  return ind
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
