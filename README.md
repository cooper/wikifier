# wikifier

This is a simple Perl parser for a clean and productive wiki language. It is primarily
used on NoTrollPlzNet Library's online database.

## Parsing stages

This describes the stages of parsing.

1. __Comment removal__: comments are removed before anything else. There is currently no way to escape the comment syntax.
2. __Line parsing__ (preparsing): data is parsed line by line. This is the stage in which variable declarations are parsed. For this reason, variable declarations must exist only one-per-line and occupy the entire line.
3. __Master parser__: data is parsed character-by-character to separate it into blocks.
4. __Block parsers__: each block type implements its own parser which parses the data within the block. Container blocks, such as sections, may also make use of the master parser one or more additional times.
