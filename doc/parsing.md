# Parsing

The Wikifier source language is parsed hierarchically.

## Parsing stages

The parsing process is divided into stages in the following order.

1. [__Master parser__](#master-parser): Data is parsed character-by-character to
separate it into several blocks. Additionally, variable definitions are handled,
and comments are removed. Anything within a block (besides comments and other
blocks) is untouched by the master parser.

2. [__Block parsers__](blocks.md): Each block type implements its own parser
which parses the data within the block. Block types can be hereditary, in which
case they may rely on another block type for parsing. [Map](blocks.md#map) and
[List](blocks.md#list) are the most common parent block types.

3. [__Formatting parser__](language.md#text-formatting): Many block parsers make
use of a formatting parser afterwards, the one which converts text formatting
such as `[b]` and `[i]` to bold and italic text, etc. Values in
[variable assignment](language.md#assignment) are also formatted.

## Master parser

The master parser is concerned only with the most basic syntax:
* Dividing the source into [blocks](language.md#blocks)
* Stripping [comments](language.md#comments)
* [Variable assignment](language.md#assignment)

The parser pushes any content it encounters to the current catch. A **catch**
defines a location where content should be pushed along with other information
about this location:

| Key           | Type              | Description                                                       | Required? |
| -----         | -----             | -----                                                             | -----     |
| `name`        | String            | Type of catch                                                     | Yes       |
| `hr_name`     | String            | Human-readable description of the catch, used in warnings/errors  | Yes       |
| `location`    | Array reference   | Where content will be pushed                                      | Yes       |
| `position`    | Array reference   | Where position info will be pushed                                |           |
| `parent`      | Catch             | Catch we will return to when this one closes                      |           |
| `valid_chars` | Compiled regex    | Characters that are allowed in the catch                          |           |
| `skip_chars`  | Compiled regex    | Characters that should be silently ignored                        |           |
| `prefix`      | Array reference   | `[prefix, pos]`; prefix to be injected on skip_chars              |           |
| `nested_ok`   | Boolean           | True if we should allow the catch elsewhere than top-level        |           |
| `is_block`    | Boolean           | True for blocks so that we know to reset `$c->block`              |           |
| `is_toplevel` | Boolean           | True only for the main block                                      |           |
