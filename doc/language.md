# Language

Wikifier's source language is designed to be easily legible by the naked eye.

## Blocks

The fundamental component of the Wikifier language is the block.
The syntax for a block is as follows:

```
Type [Name] { Content }
```
* __Type__ - The kind of block. The block type provides a unique
  function. For instance, [`imagebox{}`](blocks.md#imagebox) displays a bordered
  image with a caption and link to the full size original.
* __Name__ - Depending on its type, a block may have a name. Each block type
  may use the name field for a different purpose. For example,
  [`infobox{}`](blocks.md#infobox) uses the field to display a title bar across
  the top of the info table.
* __Content__ - Inside the block, there may be additional blocks and/or text.
  Each block handles the content within differently. Some may treat it as
  plain text, while others may do further parsing on it.

See [Blocks](blocks.md) for a list of built-in block types.

#### Nameless blocks

```
blocktype {
    ...
}
```

Example
```
imagebox {
    desc:   [[Foxy]], supreme librarian;
    align:  left;
    file:   foxy2.png;
    width:  100px;
}
```

#### Named blocks

```
blocktype [block name] {
    ...
}
```

Example
```
sec [Statistics] {
    NoTrollPlzNet Library's online division currently hosts
    [@stats.site.articles] articles.
}
```

#### Model shorthand

Wikifier has a special syntax for using [models](models.md). Write them like any
block, except prefix the model name with a dollar sign (`$`).

```
$my_model {
    option1: Something;
    option2: Another option;
}
```
Note: From within the model source, those options can be retrieved with
`@m.option1` and `@m.option2`.

Same as writing the long form:
```
model [my_model] {
    option1: Something;
    option2: Another option;
}
```

#### Blocks in variables

Blocks can be stored in variables and displayed later.

```
/* store the infobox in a variable */
@person: infobox [Britney Spears] {
    First name:     Britney;
    Last name:      Spears;
    Age:            35;
};

/* display the infobox */
{@person}
```

## Variables

Wikifier supports string, boolean, and block variables.

### Assignment

String variables look like this:
```
@some_variable:     The value;
@another_variable:  You can escape semicolons\; I think;
```

Boolean variables look like this:
```
@some_bool;
```

Block variables look like this:
```
@my_box: infobox [United States of America] {
    Declaration:    1776;
    States:         50;
};
```

### Retrieval

Once variables are assigned, they are typically used in
[formatted text](#text-formatting) or [conditionals](#conditionals). You can use
variables anywhere that formatted text is accepted like this:
```
sec {
    This is a paragraph inside a section. I am allow to use [b]bold text[/b],
    as well as [@variables].
}
```

If the variable contains a block, you can display it using `{@var_name}`. This
syntax works anywhere, not just in places where formatted text is accepted
like with the `[@var_name]` syntax. So if you have:
```
@my_box: infobox [United States of America] {
    Declaration:    1776;
    States:         50;
};
```
You would display the infobox later using:
```
{@my_box}
```

### Formatted variables

By the way, you can use text formatting within string variables, including other
embedded variables:
```
@site:      [b]MyWiki[/b];
@name:      John;
@welcome:   Welcome to [@site], [@name].
```

If you don't want that to happen, take a look at
[interpolable variables](#interpolable-variables).

### Attributes

Variables can have attributes. This helps to organize things:
```
@page.title:    Hello World!;
@page.author:   John Doe;
```

You don't have to worry about whether a variable exists to define attributes on
it. A new variable will be created on the fly if necessary (in the above
example, `@page` does not initially exist but is created automatically).

Some block types support attribute fetching and/or setting:
```
/* define the infobox in a variable so we can access attributes */
@person: infobox [Britney Spears] {
    First name:     Britney;
    Last name:      Spears;
    Age:            35;
};

/* display the infobox */
{@person}

/* access attributes from it elsewhere
   btw this works for all map-based block types */
sec {
    Did you know that [@person.First_name] [@person.Last_name] is
    [@person.Age] years old?
}
```

Some data types may not support attributes at all. Others might only support
certain attributes. For example, [`list{}`](blocks.md#list) only allows
numeric indices.
```
@alphabet: list {
    a;
    b;
    c;
    ... the rest;
};

sec {
    Breaking News: [@alphabet.0] is the first letter of the alphabet,
    and [@alphabet.25] is the last.
}
```

### Conditionals

You can use conditionals `if{}`, `elsif{}`, and `else{}` on variables. Currently
all that can be tested is the boolean value of a variable. Boolean and block
variables are always true, and all strings besides zero are true.
```
if [@page.draft] {
    Note to self: Don't forget to publish this page.
}
else {
    Thanks for checking out my page.
}
```

### Interpolable variables

Interpolable variables allow you to evaluate the formatting of a string variable
at some point after the variable was defined.

Normally the formatting of string variables is evaluated immediately as the
variable is defined.
```
@another_variable: references other variables;
@my_text: This string variable has [b]bold text[/b] and [@another_variable];
/* ok, @my_text now is:
   This string variable has <strong>bold text</strong> and references
   other variables
*/
```

Interpolate variables (with the `%` sigil) are different in that their contents
are evaluated as they are accessed rather than as they are defined.
```
@another_variable: references other variables;
%my_text: This string variable has [b]bold text[/b] and [@another_variable];
/* ok, @my_text now is:
   This string variable has [b]bold text[/b] and [@another_variable];
*/
```
Now the variable is defined with the formatting still unevaluated, so
accessing it as `[@my_text]` would display the raw formatting code. Instead,
we use `[%my_text]` to display it which tells the parser to format the
contents of the variable as we retrieve its value.

Whether you defined the variable with `@` or `%` sigil does not concern the
parser. Therefore if you do something like:
```
@my_text: This string variable has [b]bold text[/b];
```
and then try to display it with `[%my_text]`, the variable will be
double-formatted, resulting in ugly escaped HTML tags visible to clients.

### Special variables

`@page` contains information about the current page. Its attributes are set at
the very top of a page source file.

* `@page.title` - Human-readable page title. Utilized internally by the
  Wikifier, so it is required for most purposes. Often used as the `<title>` of
  the page, as well as in the `<h1>` above the first `section{}` block. The
  title can contain [formatted text](#text-formatting), but it may be stripped
  down to plaintext in certain places.
* `@page.created` - UNIX timestamp of the page creation time. This is not used
  in the Wikifier itself, but can be used in frontends for sorting the page list
  by creation date.
* `@page.author` - The name of the page author. This is also optional but may be
  used by frontends to organize pages by author.
* `@page.draft` - This boolean value marks the page as a draft. This means that
  it will not be served to unauthenticated users or cached.

`@category` is used to mark the page as belonging to a category. Each attribute
of it is a boolean. If present, the page belongs to that category. Example:
* `@category.news;`
* `@category.important;`

`@m` is a special variable used in [models](models.md). Its attributes are
mapped to any options provided in the model block.

## Text formatting

Many block types can contain formatted text. Square brackets `[` and `]` are
used for text formatting tokens.

**Basic formatting**
* `[b]bold text[/b]` - **bold text**
* `[s]strikethrough text[/s]` - ~~strikethrough text~~
* `[i]italicized text[/i]` - *italicized text*
* `superscript[^]text[/^]` - superscript<sup>text</sup>
* `subscript[v]text[/v]` - subscript<sub>text</sub>
* `[Aquamarine]some colored text[/]`

**Variables**
* `[@some.variable]` - normal variable
* `[%some.variable]` - interpolable variable
* See [Variables](#variables) above

**Links**
* `[[ Page name ]]` - internal wiki page link
* `[! Page name !]` - external wiki page link
* `[~ Cat name ~]` - category link
* `[$ http://google.com $]` - external site link
* For any link type, you can change the display text:
  `[$ Google | http://google.com $]`

**References**
* `[ref]` - a fake reference. just to make your wiki look credible.
* `[1]` - an actual reference number. a true reference.

**Characters**
* `[nl]` - a line break
* `[--]` - an en dash
* `[---]` - an em dash
* `[&copy]` - HTML entities by name
* `[&#34]` - HTML entities by number
