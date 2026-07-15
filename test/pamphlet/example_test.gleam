import gleam/set
import pamphlet
import pamphlet/djot

pub fn cheerful_symbol_render(text: String) -> String {
  let renderer =
    djot.Renderer(..djot.default(), resolve_symbol: fn(name) {
      fn(callback) {
        case name {
          "-1" -> ":+1:"
          name -> ":" <> name <> ":"
        }
        |> callback
      }
    })

  let #(_frontmatter, doc) = pamphlet.parse(text)
  djot.to_markup(doc, renderer)(fn(x) { x })
}

pub fn cheerful_render_test() {
  let out =
    ":-1: and :+1:"
    |> cheerful_symbol_render()
  assert ":+1: and :+1:" == out
}

pub fn check_turd_symbol_render(text: String) -> Result(String, Nil) {
  let renderer =
    djot.Renderer(..djot.default(), resolve_symbol: fn(name) {
      fn(callback) {
        case name {
          "turd" -> Error(Nil)
          name -> callback(":" <> name <> ":")
        }
      }
    })

  let #(_frontmatter, doc) = pamphlet.parse(text)
  djot.to_markup(doc, renderer)(Ok)
}

pub fn check_render_test() {
  let out =
    ":-1: and :+1:"
    |> check_turd_symbol_render()
  assert Ok(":-1: and :+1:") == out

  let out =
    ":turd: and :+1:"
    |> check_turd_symbol_render()
  assert Error(Nil) == out
}

pub fn list_symbols_render(text) {
  let renderer =
    djot.Renderer(..djot.default(), resolve_symbol: fn(name) {
      fn(callback) {
        let #(page, acc) = callback(":" <> name <> ":")
        #(page, set.insert(acc, name))
      }
    })

  let #(_frontmatter, doc) = pamphlet.parse(text)
  djot.to_markup(doc, renderer)(fn(page) { #(page, set.new()) })
}

pub fn list_symbols_render_test() {
  let #(page, symbols) =
    ":-1: and :+1:"
    |> list_symbols_render()
  assert ":-1: and :+1:" == page
  assert set.from_list(["-1", "+1"]) == symbols
}
