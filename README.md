# Wikifier

Wikifier is a wiki software suite. It consists of several packages that each
provide different levels of functionality. Wikifier is designed to be extensible
and independent of any web server.

## Example

So this is what is looks like.

```
@page.title:    Wikifier;
@page.author:   Mitchell Cooper;

@category.wiki;
@category.software;

infobox {
    image {
        file: wikifier-logo.png;
    };
    Type:           [! Wiki !] suite;
    Established:    February 2013;
    Author:         [$ Mitchell Cooper | https://github.com/cooper $];
    Website:        [$ https://github.com/cooper/wikifier $];
}

sec {
    Wikifier is a wiki software suite. It is unique because it is completely
    file-based. There are no databases. Yet, it offers page caching, image
    sizing, session management/authentication, and lots of other things that
    fancy wikis use databases for.

    history {
        February 2013:  The first commit of Wikifier is published.;
        December 2013:  [! Nelson Mandela !] passes away.;
        February 2014:  [! Ebola virus !] spreads across West Africa.;
        July 2015:      [! NASA !] takes a close-up photo of Pluto.;
    }
}

sec [Components] {
    Wikifier is split up into several packages.

    sec [Wikifier] {
        Provides parsing and stuff. The most basic stuff. You usually
        don't use it directly.
    }

    sec [Wikifier::Page] {
        An object representing a single page. This, you might use directly.
        Probably not though. You might use Wikifier::Wiki instead since it has
        some cool stuff.
    }

    sec [Wikifier::Wiki] {
        This one does some cool stuff. In addition to dealing with one page at
        a time, it can manage images and categories and whatnot. You
        [i]might[/i] use this directly, but you'll probably just set up a
        Wikifier::Server instead.
    }

    sec [Wikifier::Server] {

        imagebox {
            file:           wikiserver-logo.png;
            width:          200px;
            description:    Wikifier::Server logo;
        }

        This one does the actual serving of pages and stuff. Well, not really.
        It depends. You used to use a Wikifier::Page or Wikifier::Wiki directly
        from some script running on your web server.

        Now though, the wiki server approach is better. Your web server scripts
        connect to it via a UNIX socket. Then it asks for content. The server
        has lots of features on its own as well, such as read/write
        authentication, automatic compilation on edits, and more.
    }
}
```

## Documentation

* [Language](doc/language.md) - Specification for the Wikifier source language
* [Blocks](doc/blocks.md) - Built-in block types
* [Parsing](doc/parsing.md) - Wikifier parsing stages
* [Models](doc/models.md) - Explanation of Wikifier templates
* [Styling](doc/styling.md) - Using CSS in Wikifier source
* [Components](doc/components.md) - Info about Wikifier programming interfaces
