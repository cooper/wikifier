## Parsing stages

The parsing process is divided into stages in the following order.

1. __Master parser__: Data is parsed character-by-character to separate it into
several blocks. Additionally, variable definitions are handled, and comments are
removed. Anything within a block (besides comments and other blocks) is
untouched by the master parser.

2. __Block parsers__: Each block type implements its own parser which parses the
data within the block. Block types can be hereditary, in which case they may
rely on another block type for parsing. [Map](blocks.md#map) and
[List](blocks.md#list) are the most common parent block types.

3. __Formatting parser__: Many block parsers make use of a formatting parser
afterwards, the one which converts text formatting such as [b] and [i] to bold
and italic text, etc. Variables are also formatted.
