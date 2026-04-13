" syntax/vela.vim
" Syntax highlighting for Vela Single-File Components.
" Falls back gracefully when no Tree-sitter parser is available.

if exists("b:current_syntax")
  finish
endif

" ─────────────────────────────────────────────
"  Include embedded languages for each section
" ─────────────────────────────────────────────

" Embed JavaScript inside <script>...</script>
syntax include @JavaScript syntax/javascript.vim
unlet b:current_syntax

" Embed CSS inside <style>...</style>
syntax include @CSS syntax/css.vim
unlet b:current_syntax

" Embed HTML inside <template>...</template>
syntax include @HTML syntax/html.vim
unlet b:current_syntax

" ─────────────────────────────────────────────
"  SFC section tags
" ─────────────────────────────────────────────

syntax region velaScriptSection
  \ matchgroup=velaSectionTag
  \ start="<script>"
  \ end="</script>"
  \ contains=@JavaScript,velaReactiveKeyword,velaLifecycle,velaDispatch

syntax region velaStyleSection
  \ matchgroup=velaSectionTag
  \ start="<style>"
  \ end="</style>"
  \ contains=@CSS

syntax region velaTemplateSection
  \ matchgroup=velaSectionTag
  \ start="<template>"
  \ end="</template>"
  \ contains=@HTML,velaControlFlow,velaInterpolation,velaDirectiveAttr,velaComponentTag

" ─────────────────────────────────────────────
"  Reactive keywords (inside <script>)
" ─────────────────────────────────────────────

" $state, $derived, $effect, $bindable
syntax match velaReactiveKeyword "\$\(state\|derived\|effect\|bindable\)\ze\s*("
  \ contained

" onMount, onDestroy
syntax match velaLifecycle "\<\(onMount\|onDestroy\)\ze\s*("
  \ contained

" $$dispatch
syntax match velaDispatch "\$\$dispatch\ze\s*("
  \ contained

" ─────────────────────────────────────────────
"  Template control flow
" ─────────────────────────────────────────────

" {#if condition}  {#each items as item (key)}  {:else if cond}  {/if}
syntax region velaControlFlow
  \ matchgroup=velaBlockDelim
  \ start="{[#/:]"
  \ end="}"
  \ contained
  \ contains=velaBlockKeyword,velaBlockExpr

syntax keyword velaBlockKeyword
  \ if each else await then catch
  \ contained

syntax match velaBlockExpr "[^}]*"
  \ contained

" ─────────────────────────────────────────────
"  Template interpolation { expr }
" ─────────────────────────────────────────────

syntax region velaInterpolation
  \ matchgroup=velaInterpolDelim
  \ start="{[^#/:@!]"me=e-1
  \ start="{[^#/:@!]"
  \ end="}"
  \ contained
  \ contains=@JavaScript

" ─────────────────────────────────────────────
"  Directive attributes :prop= and @event=
" ─────────────────────────────────────────────

" :propName="expr"
syntax match velaBindDirective
  \ ":\w\+\ze\s*="
  \ contained

" @eventName="handler"
syntax match velaEventDirective
  \ "@\w\+\ze\s*="
  \ contained

syntax cluster velaDirectiveAttr
  \ contains=velaBindDirective,velaEventDirective

" ─────────────────────────────────────────────
"  Component tags (Uppercase)
" ─────────────────────────────────────────────

syntax match velaComponentTag
  \ "<\/\?\zs[A-Z][A-Za-z0-9]*\ze[\s/>]"
  \ contained

" svelte:fragment
syntax match velaSpecialTag
  \ "<\/\?svelte:[a-z]\+"
  \ contained

" ─────────────────────────────────────────────
"  Highlight groups → default link targets
" ─────────────────────────────────────────────

highlight default link velaSectionTag         Structure
highlight default link velaReactiveKeyword    Statement
highlight default link velaLifecycle          Function
highlight default link velaDispatch           Function
highlight default link velaBlockDelim         Delimiter
highlight default link velaBlockKeyword       Keyword
highlight default link velaBlockExpr          Normal
highlight default link velaInterpolDelim      Delimiter
highlight default link velaBindDirective      Type
highlight default link velaEventDirective     Special
highlight default link velaComponentTag       Identifier
highlight default link velaSpecialTag         Special

let b:current_syntax = "vela"
