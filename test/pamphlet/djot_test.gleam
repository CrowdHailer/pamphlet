import birdie
import jot
import midas/continuation
import pamphlet/djot

// block tests

pub fn heading_test() {
  "# A
long heading

## and a second"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("heading_test")
}

pub fn thematic_break_test() {
  "---"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("thematic_break_test")
}

pub fn codeblock_test() {
  "```
wash()
```"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("codeblock_test")
}

pub fn codeblock_language_test() {
  "```gleam
pub fn wash() { Nil }
```"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("codeblock_language_test")
}

pub fn codeblock_ticks_test() {
  "````
contains ``` ticks
````"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("codeblock_ticks_test")
}

pub fn raw_block_test() {
  "````=html
<div data-code=\"```\">Spotless</div>
````"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("raw_block_test")
}

pub fn rewrite_raw_blocks_test() {
  // render raw html as visible source instead of injecting it
  let renderer =
    djot.Renderer(..djot.default(), resolve_raw_block: fn(_content) {
      continuation.return("RAW HTML")
    })

  "
Title

````=html
<div data-code=\"```\">Spotless</div>
````"
  |> jot.parse()
  |> djot.to_markup(renderer)
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("rewrite_raw_block_test")
}

pub fn div_test() {
  ":::
Wash first
:::"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("div_test")
}

pub fn div_class_test() {
  "::: laundry
# Laundry

- Wash
- Dry

:::"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("div_class_test")
}

pub fn block_attributes_test() {
  "{#intro .lead data-mode=fast}
Wash first

{#quote .important}
> Dry second

{#code .sample}
```gleam
pub fn wash() { Nil }
```

{#panel .wide}
::: laundry
Fold third
:::"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("block_attributes_test")
}

pub fn block_quote_test() {
  "> Wash first
> Dry second"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("block_quote_test")
}

pub fn block_quote_blocks_test() {
  "> # Laundry
>
> - Wash
> - Dry"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("block_quote_blocks_test")
}

pub fn bullet_list_test() {
  "- Wash
- Dry"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("bullet_list_test")
}

pub fn bullet_list_styles_test() {
  "* Wash
* Dry

+ Fold
+ Put away"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("bullet_list_styles_test")
}

pub fn bullet_list_loose_test() {
  "- Loose

- List"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("bullet_list_loose_test")
}

pub fn ordered_list_test() {
  "1. Wash
2. Dry"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("ordered_list_test")
}

pub fn ordered_list_start_test() {
  "3. Wash
4. Dry"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("ordered_list_start_test")
}

pub fn ordered_list_ordinals_test() {
  "a. Wash
b. Dry

A. Fold
B. Put away"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("ordered_list_ordinals_test")
}

pub fn ordered_list_punctuation_test() {
  "1) Wash
2) Dry

(A) Fold
(B) Put away"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("ordered_list_punctuation_test")
}

pub fn ordered_list_loose_test() {
  "1. Loose

2. List"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("ordered_list_loose_test")
}

// inline tests

pub fn linebreak_test() {
  "one\\
two"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("linebreak_test")
}

pub fn non_breaking_space_test() {
  "one\\ two"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("non_breaking_space_test")
}

pub fn url_link_test() {
  "[Spotless](https://spotless.run)"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("url_link_test")
}

pub fn custom_link_test() {
  let renderer =
    djot.Renderer(..djot.default(), resolve_url: fn(in) {
      assert "guide://123" == in
      continuation.return("/guides/123.md")
    })
  "[guide](guide://123)"
  |> jot.parse()
  |> djot.to_markup(renderer)
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("custom_link_test")
}

pub fn reference_link_test() {
  "[Spotless][site]"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("reference_link_test")
}

pub fn image_test() {
  "![Spotless](https://spotless.run/logo.png)"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("image_test")
}

pub fn reference_image_test() {
  "![Spotless][logo]"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("reference_image_test")
}

pub fn inline_attributes_test() {
  "[Spotless](https://spotless.run){#site .external title=Spotless}

[Docs][docs]{.reference}

![Logo](https://spotless.run/logo.png){#logo .rounded}

![Badge][badge]{.icon}

[read the manual]{.big .red}"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("inline_attributes_test")
}

// Not parsed by djot
// pub fn rewrite_raw_inlines_test() {
//   // escape raw inline html instead of injecting it
//   let renderer =
//     djot.Renderer(..djot.default(), resolve_raw_inline: fn(content) {
//       continuation.return(content)
//     })

//   "before `<b>bold</b>`{=html} after"
//   |> jot.parse()
//   |> djot.to_markup(renderer)
//   |> fn(m) { m(fn(x) { x }) }
//   |> birdie.snap("rewrite_raw_inlines_test")
// }

pub fn footnote_test() {
  "[^foo]"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("footnote_test")
}

pub fn superscript_test() {
  "^tm^"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("superscript_test")
}

pub fn subscript_test() {
  "~one~"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("subscript_test")
}

pub fn symbol_test() {
  "My reaction is :+1: :smiley:."
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("symbol_test")
}

pub fn rewrite_symbol_test() {
  let renderer =
    djot.Renderer(..djot.default(), resolve_symbol: fn(name) {
      case name {
        "smiley" -> continuation.return("😊")
        name -> continuation.return(":" <> name <> ":")
      }
    })

  "My reaction is :+1: :smiley:."
  |> jot.parse()
  |> djot.to_markup(renderer)
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("rewrite_symbol_test")
}

pub fn mark_test() {
  "This is {=highlighted=}."
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("mark_test")
}

pub fn math_inline_test() {
  "Einstein derived $`e=mc^2`."
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("math_inline_test")
}

pub fn math_display_test() {
  "$$` x^n + y^n = z^n `"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("math_display_test")
}

pub fn verbatim_test() {
  "``Verbatim with a backtick` character``"
  |> jot.parse()
  |> djot.to_markup(djot.default())
  |> fn(m) { m(fn(x) { x }) }
  |> birdie.snap("verbatim_test")
}
