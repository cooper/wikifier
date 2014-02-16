# Wikifier

Wikifier is a wiki software suite. It consists of several packages that each provide
different levels of functionality. Wikifier is designed to be extensible and independent
of any web server.

## Language

The Wikifier's unique language is designed specifically for easy legibility.

### Blocks

The fundamental component of the wikifier language is the block. Each block belongs to a
specific, and each type provides a different function. For example, infobox{} displays a
table of information associated with an article. imagebox{} displays an image preview with
a caption and link to a full-sized image.
  
Many blocks may contain text as well as other blocks. Each block may handle the data
inside of it differently.

#### Syntax

Blocks can have names: Some do, and some don't. Each block type may use this name for
different purposes. For example, section blocks use the title to display a header over
the section. Infoboxes use the title to display a title along the top of the box. The
syntax for blocks is as follows.
  

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

## Packages

The most basic package is Wikifier. It provides the minimal functionality for parsing
and handling wiki language source files. The package is divided into several subpackages:

* __Parser__: reads wiki language source files character-by-character and parses them.
* __Formatter__: formats wiki language text, such as bolds, italics, and links.
* __BlockManager__: dynamically loads and creates block objects.
* __Utilities__: provides convenience functions used throughout the software.

The Wikifier package alone does not provide many functions. It is not intended to be used
directly. Instead, a Wikifier::Page or Wikifier::Wiki should be utilized.

### Wikifier::Page

Wikifier::Page is the most basic functional interface to the Wikifier. As the name
suggests, a Wikifier::Page object represents a single page of a wiki. Wikifier::Page
utilizes the Wikifier package to generate HTML.

### Wikifier::Wiki

Wikifier::Wiki is an optional component of Wikifier. Wikifier::Page is designed to be
completely independent of Wikifier::Wiki. This class provides a full wiki manager. It
features image generation, category management, and other components of many wikis.

### Wikifier::Server

In the past, Wikifier::Wikis were used directly by Perl modules of web servers. However,
Wikifier::Server provides a new mechanism for web servers to utilize Wikifier whether
or not they have a Perl module. Any web script of any kind may utilize a Wikifier::Server
by connecting to it over a socket, typically of the UNIX domain. The server then sends
the output for each request, and the web script may inject it into a web page with a
template engine or something similar.

## Parsing stages

The parsing process is divided into several stages in the following order.

1. __Comment removal__: comments are removed before anything else. There is currently no
way to escape the comment syntax.

2. __Line parsing__ (preparsing): data is parsed line by line. This is the stage in which
variable declarations are parsed. For this reason, variable declarations must exist only
one-per-line and occupy the entire line. This stage terminates upon the end of the file or
the first occurance of \__END__.

3. __Master parser__: data is parsed character-by-character to separate it into several
blocks.

4. __Block parsers__: each block type implements its own parser which parses the data
within the block. Container blocks, such as sections, may also make use of the master
parser one or more additional times.

5. __Formatting parser__: many block parsers make use of a formatting parser afterwards,
the one which converts text formatting such as [b] and [i] to bold and italic text, etc.