## Parsing stages

The parsing process is divided into several stages in the following order.

1. __Comment removal__: comments are removed before anything else. There is
currently no way to escape the comment syntax.

2. __Line parsing__ (preparsing): data is parsed line by line. This is the stage
in which variable declarations are parsed. For this reason, variable
declarations must exist only one-per-line and occupy the entire line. This stage
terminates upon the end of the file or the first occurence of \__END__.

3. __Master parser__: data is parsed character-by-character to separate it into
several blocks.

4. __Block parsers__: each block type implements its own parser which parses the
data within the block. Container blocks, such as sections, may also make use of
the master parser one or more additional times.

5. __Formatting parser__: many block parsers make use of a formatting parser
afterwards, the one which converts text formatting such as [b] and [i] to bold
and italic text, etc.
