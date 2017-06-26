if exists("b:current_syntax")
	finish
endif

syntax match platinaAnnotationType '\v\s\@=(callee|guard|lbound)\s\@='
highlight link platinaAnnotationType Keyword

syntax match platinaQname '\v^\S+'
highlight link platinaQname Identifier

syntax match plainPeachesNumber '\d\+'
highlight link plainPeachesNumber Number

syntax match plainPeachesNumber '\d\+'
highlight link plainPeachesNumber Number

syntax keyword plainPeachesBoolean True False
highlight link plainPeachesNumber Constant

let hs_highlight_boolean = 1
syntax include @Peaches syntax/haskell.vim
syntax region  platinaString matchgroup=Peaches start=/\v"/ skip=/\v\\./ end=/\v"/ contains=@Peaches
"highlight link platinaString String
highlight link Peaches String

let b:current_syntax = "platina"
