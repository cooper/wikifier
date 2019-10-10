# SUPERSEDED BY QUIKI

Please use [quiki](https://github.com/cooper/quiki) instead, a more comprehensive
wiki suite based on the wikifier concept.

# wikifier

wikifier is a file-based wiki engine.

## Example

```
@page.title:    wikifier;
@page.author:   Mitchell Cooper;

@category.wiki;
@category.software;

infobox {
    image {
        file: wikifier-logo.png;
    };
    Type:           [[ Wiki engine | wp: Wiki software ]];
    Established:    February 2013;
    Author:         [[ Mitchell Cooper | https://github.com/cooper ]];
    Website:        [[ wikifier on GitHub | https://github.com/cooper/wikifier ]];
}

sec {
    wikifier is a wiki engine. It is unique because it is completely
    file-based. There are no databases. Yet, it offers page caching, image
    sizing, session management/authentication, and lots of other things that
    fancy wikis use databases for.

    history {
        February 2013:  The first commit of wikifier is published.;
        December 2013:  [[ wp: Nelson Mandela ]] passes away.;
        February 2014:  [[ wp: Ebola virus ]] spreads across West Africa.;
        July 2015:      [[ wp: NASA ]] takes a close-up photo of Pluto.;
    }
}

sec [Components] {
    wikifier is split up into several packages. They are listed below, with
    each subsequent one built atop the previous.

    sec [Wikifier] {
        Responsible for parsing and other low-level functions. While typically
        not used directly, this package provides the most basic implementation
        of the wikifier language.
    }

    sec [Wikifier::Page] {
        An object representing a single page. This package provides a
        programming interface for working with a single wikifier page. The
        included [c]wikifier[/c] executable uses this to read a page file and
        output HTML.
    }

    sec [Wikifier::Wiki] {
        A full wiki suite, capable of managing a diverse collection of content.
        Features page categories, templates, image generation, revision
        tracking, and much more. This package provides a programming interface
        that can be used directly from a web server script, but running a
        standalone wikiserver is preferred.
    }

    sec [Wikifier::Server] {

        imagebox {
            file:   wikiserver-logo.png;
            width:  200px;
            desc:   Wikifier::Server logo;
        }

        The included [c]wikiserver[/c] executable runs an instance of
        Wikifier::Server. A single wikiserver can manage any number of wikis.
        It monitors source files for changes and generates content immediately
        as it is modified. The result is a faster page load time since the
        content has been pregenerated.

        wikiservers do not deliver the content directly to the user. Instead,
        frontends connect to and communicate with them. These frontends, in
        turn, make it possible to view and manage wikifier wikis from the web.
        This makes it easy to incorporate wikifier into almost any web
        server without having to use disgusting Perl HTTPd modules, and it
        allows the wikiserver to perform scheduled operations independently of
        the web server.
    }
}

sec [Frontends] {
    These frontends connect to a wikiserver and deliver content to end users.
    
    sec [quiki] {
        [[ quiki | https://github.com/cooper/quiki ]] is a standalone web server
        for wikifier. Because it is designed specifically for wikifier, it is by
        far the easiest option to get a wiki up and running in a few simple
        steps. It can be incorporated into an existing web environment using a
        reverse proxy.
    }
    
    sec [adminifier] {
        [[ adminifier | https://github.com/cooper/adminifier ]] is a web-based
        administrative panel to manage wikifier wikis. It is written in PHP and
        therefore runs on a variety of web servers.
    }
}

sec [Interfaces] {
    These programming interfaces can be used to incorporate wikifier into
    other web servers.
    
    list {
        [[ go-wikiclient | https://github.com/cooper/go-wikiclient ]] -
            Go programming interface;
        [[ php-wikiclient | https://github.com/cooper/php-wikiclient ]] -
            PHP programming interface;
    }
}
```

## Getting started

[quiki](https://github.com/cooper/quiki) is currently the easiest way to get a
wikifier wiki up and running.

wikifier dependencies can be installed with
```
cpanm GD Git::Wrapper HTTP::Date HTML::Strip HTML::Entities JSON::XS URI::Escape
```

## Documentation

General
* [Language](doc/language.md)           - wikifier language specification
* [Configuration](doc/configuration.md) - wikifier configuration
* [Blocks](doc/blocks.md)               - wikifier built-in block types
* [Models](doc/models.md)               - wikifier templates
* [Styling](doc/styling.md)             - wikifier + CSS
* [Markdown](doc/markdown.md)           - wikifier + Markdown

Technical
* [Parsing](doc/technical/parsing.md)       - wikifier parsing stages
* [Components](doc/technical/components.md) - wikifier programming interfaces
* [Page](doc/technical/page.md) - Wikifier::Page API
* [Wiki](doc/technical/wiki.md) - Wikifier::Wiki API
* [Commands](doc/technical/server-commands.md) - wikiserver commands

## Contact

Go to `#k` on `irc.notroll.net`.
