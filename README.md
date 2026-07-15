# Pamphlet


[![Package Version](https://img.shields.io/hexpm/v/pamphlet)](https://hex.pm/packages/pamphlet)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/pamphlet/)


Render djot documents with custom elements and url schemes.

Rendering links, images, raw HTML, and symbols often need knowledge the document does
not have: asset fingerprints, CDN hosts, valid page routes, async manifests,
or build-time reports.
Pamphlet exposes those decisions as [continuations](https://crowdhailer.me/2026-07-15/abstracting-effects-with-continuations/).

## Targets

Pamphlet supports rendering back to djot/markdown, useful for `llm.txt` and `.md` pages and lustre for web pages and web apps.

## Front matter

Defines pages with frontmatter deliminated by `---`.
Currently parses frontmatter to string key and value list.

## Rendering

```
import pamphlet
```

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
