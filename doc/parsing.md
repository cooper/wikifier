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

### Current

Parser states are stored in the **current** object:

| Key/Method            | Type/Arguments    | Description
| -----                 | -----             | -----
| `{char}`              | Character         | current character
| `{next_char}`         | Character         | next character or an empty string if this is the last one
| `{last_char}`         | Character         | previous character or an empty string if this is the first one
| `{skip_char}`         | Boolean           | if set to true at any point, the next character will be skipped entirely
| `{line}`              | Integer           | current line number
| `{col}`               | Integer           | current column number (actually column + 1)
| `->pos`               | Position          | returns the current position as a hash
| `->catch`             | [Catch](#catch)   | fetch or set the current catch  
| `->clear_catch`       |                   | close the current catch, returning to its parent
| `->block`             | [Block](language.md#blocks) | fetch or set the current block
| `->is_comment`        | Boolean           | true if we are currently inside a [block comment](language.md#comments)
| `->mark_comment`      |                   | increment the block comment level
| `->clear_comment`     |                   | decrease the block comment level
| `->is_escaped`        | Boolean           | true if the current character was escaped (`{last_char} eq '\\'`)
| `->mark_escaped`      |                   | mark the current character as escaped
| `->clear_escaped`     |                   | clear the escape state in preparation for the next character
| `->is_ignored`        | Boolean           | true if the current character is a master parser character
| `->mark_ignored`      |                   | mark the current character as ignored
| `->clear_ignored`     |                   | clear the ignored state in preparation for the next character
| `->is_curly`          | Boolean           | true if we are currently inside a [brace-escape](language.md#escaping)
| `->mark_curly`        |                   | increment the brace-escape level
| `->clear_curly`       |                   | decrease the brace-escape level
| `->warning`           | `$pos, $message`  | push a parser warning at `$pos` or the current position if unspecified
| `->error`             | `$message`        | throw a fatal parser error. parsing of the document will be aborted
| `->push_content`      |  `@content`       | push the contents (mixed text/block) to the current catch
| `->append_content`    | `@content`        | push or append the contents (mixed text/block) to the current catch, whichever is appropriate
| `->clear_content`     |                   | purge all content and position information from the current catch
| `->last_content`      | String or [Block](language.md#blocks) | fetch or set the last element of the current catch content

### Catch

The parser pushes any content it encounters to the current catch. There is
always a catch open; at the start of a document, it is the main block. A
**catch** defines a location where content should be pushed along with other
information about this location:

| Key           | Type              | Description                                                       | Required?
| -----         | -----             | -----                                                             | -----
| `name`        | String            | Type of catch                                                     | Yes
| `hr_name`     | String            | Human-readable description of the catch, used in warnings/errors  | Yes
| `location`    | Array reference   | Where content will be pushed                                      | Yes
| `position`    | Array reference   | Where position info will be pushed                                |
| `parent`      | Catch             | Catch we will return to when this one closes                      |
| `valid_chars` | Compiled regex    | Characters that are allowed in the catch                          |
| `skip_chars`  | Compiled regex    | Characters that should be silently ignored                        |
| `prefix`      | Array reference   | `[prefix, pos]`; prefix to be injected on skip_chars              |
| `nested_ok`   | Boolean           | True if we should allow the catch elsewhere than top-level        |
| `is_block`    | Boolean           | True for blocks so that we know to reset `$c->block`              |
| `is_toplevel` | Boolean           | True only for the main block                                      |
