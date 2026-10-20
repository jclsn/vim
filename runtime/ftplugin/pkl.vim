" Vim filetype plugin
" Language:	Pkl
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2025 Jul 14
" 2025 Oct 03 by Vim Project Add foldmethod #18274

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,:///,://
setlocal commentstring=//\ %s
setlocal foldmethod=syntax
setlocal formatoptions+=croql
setlocal expandtab shiftwidth=2 softtabstop=2
setlocal suffixesadd=.pkl

let b:undo_ftplugin = 'setl com< cms< fdm<'
