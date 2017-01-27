# Components

## Wikifier

The most basic package is Wikifier. It provides the minimal functionality for
parsing and handling wiki language source files. The package is divided into
several subpackages:

* __Parser__: reads wiki language source files character-by-character and parses
    them.
* __Formatter__: formats wiki language text, such as bolds, italics, and links.
* __BlockManager__: dynamically loads and creates block objects.
* __Utilities__: provides convenience functions used throughout the software.

The Wikifier package alone does not provide high-level functionality. It is not
intended to be used directly. Instead, a Wikifier::Page or Wikifier::Wiki should
be utilized.

## Wikifier::Page

Wikifier::Page is the most basic functional interface to the Wikifier. As the
name suggests, a Wikifier::Page object represents a single page of a wiki.
Wikifier::Page utilizes the Wikifier package to generate HTML from a page
source code.

## Wikifier::Wiki

Wikifier::Wiki is an optional component of Wikifier. Wikifier::Page is designed
to be completely independent of Wikifier::Wiki. This class provides a full wiki
manager. It features image generation, category management, and other components
of many wikis.

## Wikifier::Server

In the past, Wikifier::Wikis were queried directly by Perl modules running on
web servers. Wikifier::Server provides a new mechanism for web servers to
utilize Wikifier whether or not they have a Perl module loaded. This makes
Wikifier::Wiki far more portable.

A web script of any kind may utilize a Wikifier::Server by connecting to it over
a socket, typically of the UNIX domain. The server then sends the output for
each request, and the web script may inject it into a web page with a template
engine or something similar.

Wikifier::Server also features automatic precompilation. In other words, the
server listens for changes to wiki source files and compiles them on the spot.
It also pregenerates images in all the sizes that are used in the wiki.
The result is a much faster loading page, since the Wikifier::Wiki never has
to generate pages or images on demand as they are requested.

In addition to autocompiling and serving wiki pages, Wikifier::Server features
write authentication. This allows frontends such as
[adminifier](https://github.com/cooper/adminifier) to commit changes to the
wiki directly from a web interface.

## Interfaces

Wikifier::Server is not a web server. You have to link your web server to it
with some sort of script. Wikifier comes with some programming interfaces to do
this. They are located in the [interfaces](../interfaces) directory.

Documentation for each interface:
* [__PHP__](../interfaces/PHP/README.md)
