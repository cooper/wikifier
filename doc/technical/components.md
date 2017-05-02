# Components

wikifier is divided into several components, each built atop the previous.
This allows it to be used either as a wiki library or as a
[standalone program](#executables).

* [Components](#components)
  * [Wikifier](#wikifier) - Low-level parsing and HTML generation
  * [Wikifier::Page](#wikifierpage) - Programming interface for a single page
  * [Wikifier::Wiki](#wikifierwiki) - Programming interface for a wiki site
  * [Wikifier::Server](#wikifierserver) - Transport wiki content to a web server
     * [Features](#features)
     * [Usage](#usage)
     * [Interfaces](#interfaces)
  * [Executables](#executables) - Use wikifier as a standalone program

## wikifier

The **Wikifier** package includes the most basic low-level functions. It
provides the minimal functionality for parsing wiki source files and generating
HTML. This is not to be used directly; instead set up a
[wikiserver](#wikifierserver) or use one of [WiPage](#wikifierwiki) or
[WiWiki](#wikifierwiki) directly from code.

The wikifier package is divided into several subpackages:
* __Parser__ - Reads [wiki language](../language.md) source files
  character-by-character and [parses](parsing.md) them.
* __Formatter__ - Translates [formatted text](../language.md#text-formatting) such
 as bolds, italics, and links to HTML.
* __BlockManager__ - Dynamically loads and creates [blocks](../language.md#blocks).
* __Block__ - Base class of all blocks.
* __Element__ - Represents a single HTML element.
* __Elements__ - Represents a group of HTML elements.
* __Utilities__ - Provides convenience functions used throughout the software.

## Wikifier::Page

**WiPage** (Wikifier::Page) is the most basic interface to the wikifier. As the
name suggests, a Wikifier::Page object represents a single page of a wiki.
Usually it is associated with a single `.page` file written in the
[wikifier language](../language.md). WiPage utilizes the wikifier package to
generate HTML from the source file.

## Wikifier::Wiki

**WiWiki** (Wikifier::Wiki) is an optional component of wikifier which each
WiPage is independent of. This class provides a full wiki manager featuring
caching, image generation, category management, templates, and other components
of many wikis.

Wikifier::Wiki is further divided into a few parts:
* __Pages__:        Generate and display pages.
* __Images__:       Generate and display images.
* __Categories__:   Generate and maintain category files.
* __Models__:       Generate models.
* __Revision__:     Wiki revision tracking.

## Wikifier::Server

Wikifier::Server implements the **wikiserver**, a program which serves wiki
content dynamically. It is *not* a web server. Instead, web servers communicate
with it via a UNIX socket. This makes it very portable (independent of any
specific web server's module APIs), and it allows the wikiserver to perform
operations independent of the web server.

### Features

In the past, [WiWikis](#wikifierwiki) were queried directly by Perl modules
running on web servers. The new wikiserver is a much better solution because it
allows the web script to be written in any language. Consequently you can use
any template engine with Wikifier.

The wikiserver also features automatic precompilation and image pregeneration.
In other words, the server listens for changes to wiki source files and compiles
them on the spot, generating images in all the required sizes. The result is a
much faster page load, since the WiWiki never has to generate pages on demand
as they are requested.

In addition to autocompiling and serving wiki pages, the wikiserver features
write access authentication. This allows frontends such as
[adminifier](https://github.com/cooper/adminifier) to commit changes to the
wiki directly from a web interface.

One wikiserver can manage any number of [WiWikis](#wikifierwiki).

### Usage

1. For each wiki, you will need to write a
   [WiWiki configuration](../configuration.md#wikifierwiki-public-options).
2. Once your wikis are configured, write a
   [wikiserver configuration](../configuration.md#wikifierserver-options).
3. Set up a [web script](#interfaces) to connect to the wikiserver.
4. Run the included `wikiserver` program.

```
./wikiserver /path/to/wikiserver.conf
```

### Interfaces

[Wikifier::Server](#wikifierserver) is *not* a web server. You have to link your
web server to it with some sort of script. wikifier comes with some programming
interfaces to do this. They are located in the [interfaces](../interfaces)
directory.

* __PHP__ - [php-wikiclient](https://github.com/cooper/php-wikiclient)
* __Go__ - [go-wikiclient](https://github.com/cooper/go-wikiclient)

### Frontends

These connect to wikiservers in order to serve content via HTTP.

* [__quiki__](https://github.com/cooper/quiki) - a standalone web server for
  wikifier written in Go. probably the easiest way to get a wikifier wiki up and
  running. features a built-in template engine, the ability to serve multiple
  wikis from one server, and more.
* [__adminifier__](https://github.com/cooper/adminifier) - an administrator
  panel for wikifier written in PHP.

## Executables

These executables, included in the wikifier distribution, make it possible to
use wikifier as an independent program rather than a library.

### wikifier

```
./wikifier /path/to/some.page
```

Reads the provided wiki page source file, spitting out the generated HTML to
STDOUT. Warnings and errors are written to STDERR. Exit status is nonzero on
fatal error.

### wikiserver

```
./wikiserver /path/to/wikiserver.conf
```

Runs a [wikiserver](#wikifierserver).

### wikiclient

```
./wikiclient /path/to/wikiserver.conf
```

Connects to a [wikiserver](#wikiserver) with an input prompt. This is only for
testing so you can see how the wikiserver fulfills requests.
