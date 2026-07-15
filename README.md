# Pamphlet

Render djot documents with custom elements and url schemes.

## Front matter

Defines pages with frontmatter deliminated by `---`.
Currently parses frontmatter to string key and value list.

## Rendering

Both targets resolve the special forms of a document — the parts whose
meaning belongs to the host application, like link URLs — through a
`Renderer` whose lookups return `Cont` values from the
[`cont`](../cont) package:

- `pamphlet/djot` renders back to djot flavoured markup. Its renderer
  resolves link and image URLs.
- `pamphlet/lustre` renders to a lustre element tree, following
  `jot.document_to_html`. Its renderer resolves URLs, raw blocks, raw
  inlines and symbols.

A pure lookup is `cont.pure`; an effectful one can use the answer type
however it likes — halt with a `Result`, thread state, await a promise —
without any change to the traversal. The [examples](./examples) directory
holds a runnable project for each of these shapes.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
