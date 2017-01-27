# Blocks

This is the list of built-in block types. For a syntactical explanation of
blocks, see [Language](language.md).

## Clear

Creates a `<div>` with `clear: both`.

```
clear{}
```

## Code

Used to wrap some code. The contents will not be formatted, except that
curly brackets must be escaped.

```
code {
    someCode();
    function someCode() \{
        return "You have to escape those.";
    \}
}
```

## Format

Same as [`html{}`](#html), except that text formatting is permitted. Often
used with [models](#model).

```
format {
    <div>
        This is some HTML.
        b]Wikifier formatting[/b] is allowed.
    </div>
}
```

## Hash

A hash data type. It can be used for the parameters of other blocks. Many other
block types inherit from this when they accept key-value options.

Yields no HTML.

```
hash {
    key: value;
    other key: another value;
}
```

## History

Displays a timeline of events.

```
history {
    1900: A new century began.;
    2000: A new millennium began.;
}
```

## Html

Used to embed some HTML. See also [`format{}`](#format).

```
html {
    <div>
        This is HTML. Nothing inside will be changed,
        but please note that curly brackets \{ and \}
        must be escaped.
    </div>
}
```

## Image

A simple image element. Typically for embedding standalone images with a nice
border and optional caption you should use [`imagebox{}`](#imagebox) instead.
However, `image{}` is often used inside other block types.

```
infobox [Planet Earth] {
    image {
        file: planet-earth.jpg;
        desc: Earth from space;
    };
    Type: Planet;
    Population: 23 billion;
    Galaxy: Milky Way;
}
```

## Imagebox

Embeds an image with an automatic border. It will be either left or right
aligned. It can have an optional caption. Also, clicking it takes you to the
full-sized image.

```
imagebox {
    file:   planet-earth.jpg;
    width:  300px;
    align:  right;
    desc:   Earth from space;
}
```

## Infobox

Displays a summary of information for an article. Usually there is just one
per article, and it occurs before the first section.

```
@page.title: Earth;

infobox [Planet Earth] {
    image {
        file: planet-earth.jpg;
        desc: Earth from space;
    };
    Type: [b]Planet[/b];
    Population: 23 billion;
    Galaxy: Milky Way;
}

sec {
    Welcome to my page!
}
```

## Invisible

Silences whatever's inside.

```
invisible {
    sec {
        Normally this would show a paragraph.
        But since it's inside an invisible block, it shows nothing.
    }
}
```

## List

A list datatype. It may be used by other block types. By itself though, it
yields an unordered list.

```
list {
    Item one;
    Item two;
    Item three can have an escaped semicolon\; I think;
}
```

## Model

Allows you to embed a template. See [Models](models.md).

## Paragraph

The name says it all. You can call it `paragraph{}` or `p{}`. Or you can
call it nothing because stray text within `sec{}` blocks is assumed to be a
paragraph.

```
sec [My Section] {
    p {
        A paragraph.
    }
    p {
        Another.
    }
}
```

Same as
```
sec [My Section] {
    A paragraph.

    Another.
}
```

## Section

A section is kinda like a `<div>`, except that it can also have a header. The
first section on a page always has the page title as its header, so even if
specify some text there, it will not be considered. As for the rest, the
header will be displayed at the appropriate level. Also spelled `sec{}`.

```
sec {
    This is my intro section. No need to put a title here, since the page title
    will be displayed atop this section.
}

sec [Info] {
    Here we go. This one has a title.

    By the way, a blank line starts a new paragraph.
}

sec [More stuff] {
    You can also put sections inside each other.

    sec [Little header] {
        This section will have a smaller header, since it is nested deeper
        than the top-level sections.
    }
}
```

## Style

Allows you to use CSS with Wikifier. See [Styling](styling.md).
