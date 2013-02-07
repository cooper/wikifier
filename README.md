# wikifier

This is a simple Perl parser for a clean and productive wiki language. It is primarily
used on NoTrollPlzNet Library's online database.

## Parsing stages

This describes the stages of parsing.

1. __Comment removal__: comments are removed before anything else. There is currently no way to escape the comment syntax.
2. __Line parsing__ (preparsing): data is parsed line by line. This is the stage in which variable declarations are parsed. For this reason, variable declarations must exist only one-per-line and occupy the entire line. This stage terminates upon the end of the file or the first occurance of \__END__.
3. __Master parser__: data is parsed character-by-character to separate it into several blocks.
4. __Block parsers__: each block type implements its own parser which parses the data within the block. Container blocks, such as sections, may also make use of the master parser one or more additional times.

## Blocks

Blocks make up a fundamental of this language. Each block type has a different function.
For example, infobox{} blocks display a table of information associated with an article.
imagebox{} blocks display an image preview with a caption and link to the full-size image.  
  
Some block types such as section{} can have child blocks inside of them. Other's can't.

### Syntax

Blocks can have names. Some do; some don't. Each block type may use this name for
different purposes. For example, section blocks use the title to display a header over
the section. Infoboxes use the title to display a title along the top of the box.  
  
**Nameless blocks**

```
blocktype {
    ...
}
```

```
imagebox {
    description: [[Foxy]], supreme librarian;
    align: left;
    file: foxy2.png;
    width: 100px;
}
```

**Named blocks**

```
blocktype [block name] {
    ...
}
```

```
section [Statistics] {

    paragraph {
        NoTrollPlzNet Library's online division currently hosts
        [b][@stats.site.articles][/b] articles.
    }

}
```
