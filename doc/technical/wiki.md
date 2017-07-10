# Wikifier::Wiki

`Wikifier::Wiki` is a programming interface for a file-based wiki site.

## Constructor

```perl
my $wiki = Wikifier::Wiki->new(
    config_file  => '/var/www/mywiki/wiki.conf',
    private_file => '/home/someone/mywiki-private.conf'
);
```

Creates an instance representing a wiki. This may be reused indefinitely.
Multiple instances may exist for the same wiki, such as in separate processes
or threads of a web server.

__%opts__ - hash of options
* __config_file__ - path to wiki configuration file
* __private_file__ - _optional_, path to
  [private](../configuration.md#wikifierwiki-private-options) configuration file
* __opts__ - _optional_, hard-coded wiki configuration options

## opt

```perl
say "Welcome to ", $wiki->opt('name'); # "Welcome to My Wiki!"
```

Fetches a wiki configuration option.

## verify_login

```perl
my $user = $wiki->verify_login($username, $password);
die "Login failed!\n" if !$user;
```

Verifies the credentials of a user defined in the private wiki configuration
file. Returns a hash reference of user info on success, nothing on failure.

## display_error

```perl
return display_error('Page does not exist.');
```

Procedural function, returns an error for any display method.

## unique_files_in_dir

```perl
my @images = unique_files_in_dir(
    $wiki->opt('dir.image'),
    ['png', 'jpg', 'jpeg']
);
```

Procedural function, returns a list of filenames in a directory, ignoring files
that appear more than once due to symbolic links. Optionally provide a file
extension or array reference of file extensions to accept.

## file_contents

```perl
# file_contents($path, $binary)
my $image_data = file_contents('myimage.png', 1);
```

Procedural function, slurps the entire contents of file. If `$binary` is true,
the file is treated as binary data; otherwise, it is read in UTF-8 mode.

# Pages

These methods are for managing pages in the wiki.

## display_page

```perl
my $result = $wiki->display_page($page_name, %opts);
```

Displays a page.

```
# Input
#
#   $page_name          name of the page, with or without the extension
#
#   %opts = (
#
#       draft_ok        if true, drafts will not be skipped
#
#   )
#
# Result
#
#   for type 'not found':
#
#       error           a human-readable error string. sensitive info is never
#                       included, so this may be shown to users
#
#       (parse_error)   true if the error occurred during parsing
#
#       (draft)         true if the page cannot be displayed because it has not
#                       yet been published for public viewing
#
#   for type 'redirect':
#
#       redirect        a relative or absolute URL to which the page should
#                       redirect, suitable for use in a Location header
#
#       file            basename of the page, with the extension. this is not
#                       reliable for redirects, as it may be either the name of
#                       this page itself or that of the redirect page
#
#       name            basename of the page, without the extension. like 'file'
#                       this is not well-defined for redirects
#
#       path            absolute file path of the page. like 'file' this is not
#                       well-defined for redirects
#
#       mime            'text/html' (appropriate for Content-Type header)
#
#       content         a link to the redirect target, which normally will not
#                       be displayed, but may if the frontend does not support
#                       the 'redirect' type
#
#   for type 'page':
#
#       file            basename of the page, with the extension
#
#       name            basename of the page, without the extension
#
#       path            absolute file path of the page
#
#       mime            'text/html' (appropriate for Content-Type header)
#
#       content         the page content (HTML)
#
#       mod_unix        UNIX timestamp of when the page was last modified.
#                       if 'generated' is true, this is the current time.
#                       if 'cached' is true, this is the modified date of the
#                       cache file. otherwise, this is the modified date of the
#                       page file itself
#
#       modified        like 'mod_unix' except in HTTP date format, suitable for
#                       use in the Last-Modified header
#
#       (css)           CSS generated for the page from style{} blocks. omitted
#                       when the page does not include any styling
#
#       (cached)        true if the content being served was read from a cache
#                       file (opposite of 'generated')
#
#       (generated)     true if the content being served was just generated in
#                       order to fulfill this request (opposite of 'cached')
#
#       (cache_gen)     true if the content generated in order to fulfill this
#                       request was written to a cache file for later use. this
#                       can only be true if 'generated' is true
#
#       (text_gen)      true if this request resulted in the generation of a
#                       text file based on the contents of this page
#
#       (draft)         true if the page has not yet been published for public
#                       viewing. note that unless 'draft_ok' option was used,
#                       result for drafts will be of type 'not found'
#
#       (warnings)      an array reference of warnings produced by the parser.
#                       omitted when no warnings were produced
#
#       (created)       UNIX timestamp of when the page was created, as
#                       extracted from the special @page.created variable.
#                       ommitted when @page.created is not set
#
#       (author)        name of the author of the page, as extracted from the
#                       special @page.author variable. omitted when
#                       @page.author is not set
#
#       (categories)    array reference of categories the page belongs to. these
#                       do not include the '.cat' extension. omitted when the
#                       page does not belong to any categories
#
#       (fmt_title)     the human-readable page title, as extracted from the
#                       special @page.title variable, including any possible
#                       HTML-encoded text formatting. omitted when @page.title
#                       is not set
#
#       (title)         like 'fmt_title' except that all formatting has been
#                       stripped. suitable for use in the <title> tag. omitted
#                       when @page.title is not set
#
```

## display_page_code

```perl
my $result = $wiki->display_page_code($page_name, %opts);
```

Displays the wiki source code for a page.

```
# %opts = (
#   display_page = 1  also include ->display_page result, omitting  {content}
#   display_page = 2  also include ->display_page result, including {content}
# )
#
```

## path_for_page

```perl
# $wiki->path_for_page($page_name, $create_ok)
my $path_1 = $wiki->path_for_page('some_page.page');
my $path_2 = $wiki->path_for_page('subdirectory/subpage.page', 1);
```

Returns the absolute path to a page given its name. If `$create_ok` is true,
subdirectories will be created in the page directory as needed. For security,
this should not be true unless the page is soon to be created.

## page_named

```perl
my $page_1 = $wiki->page_named('some_page'); # extension is optional
my $page_2 = $wiki->page_named('Welcome to My Wiki'); # filenames are normalized
```

Returns a [Wikifier::Page](page.md) object associated with this wiki.

## all_pages

```perl
my @page_names = $wiki->all_pages;
```

Returns a list of all page names on the wiki.

## get_pages

```perl
my $pages = $wiki->get_pages;
```

Returns a filename-to-metadata hash reference about all the pages on the wiki.

## get_page

```perl
my $page_info = $wiki->get_page('some_page.page');
```

Returns a hash reference of metadata for a page given its name.

# Categories

These methods are for managing wiki page categories.

## display_cat_posts

```perl
my $result = $wiki->display_cat_posts($cat_name, %opts);
```

Displays pages within a category in the style of blog posts.

```
# %opts = (
#
#   cat_type    category type
#
#   page_n      page number
#
# )
#
```

## path_for_category

```perl
my $path = $wiki->path_for_category('some_category.cat');
```

Returns the absolute path to a category given its name.

## cat_check_page

```perl
$wiki->cat_check_page($page);
```

After parsing a page, this is used to update categories that the page belongs to
and remove it from ones it no longer does.

## cat_add_page

```perl
$wiki->cat_add_page($page, $cat_name, %opts);
```

Adds a page to a category.

__%opts__ - hash of options

```
# %opts = (
#
#   cat_type        for pseudocategories, the type, such as 'image' or 'model'
#
#   page_extras     for pseudocategories, a hash ref of additional page data
#
#   cat_extras      for pseudocategories, a hash ref of additional cat data
#
#   create_ok       for page pseudocategories, allows ->path_for_category
#                   to create new paths in dir.cache/category as needed
#
#   preserve        if a category has no pages in it, it is purged. this option
#                   tells the wiki to preserve the category even when empty
#
#   force_update    if a category exists and $page_maybe is not provided,
#                   the category file is not rewritten. this forces rewrite
# )
```

## cat_add_image

```perl
$wiki->cat_add_image($image_name, $page, %opts);
```

Adds a page to an image category.

Same options as [`cat_add_page`](#cat_add_page).

## cat_get_pages

```perl
my ($err, $pages, $cat_title) = $wiki->cat_get_pages('some_category.cat');
```

Fetches all the pages in a category. Returns an error, a filename-to-metdata
hash reference, and the category title. The latter two are not present in the
case of an error. The title may not be present regardless.

## all_categories

```perl
my @cat_names = $wiki->all_categories;
```

Returns a list of all category names on the wiki.

# Images

These methods are for working with images on the wiki.

## display_image

```perl
my $result = $wiki->display_image($image_name, %opts);
```

Displays an image.

```
# Input
#
#   $image_name     filename string
#                   1) image.png                    full-size
#                   2) 123x456-image.png            scaled
#                   3) 123x456-image.png            scaled with retina
#                   array ref of [ filename, width, height ]
#                   4) [ 'image.png', 0,   0   ]    full-size
#                   5) [ 'image.png', 123, 456 ]    scaled
#                   6) [ 'image.png', 123, 0   ]    scaled with one dimension
#                   precompiled image name hash reference
#
#   if image.enable.restriction is true, images will not be generated in
#   arbitrary dimensions, only those used within the wiki. this can be overriden
#   with the gen_override option mentioned below.
#
#   %opts = (
#
#       dont_open       don't actually read the image; {content} will be omitted
#
#       gen_override    true for pregeneration so we can generate any dimensions
#
#   )
#
# Result
#
#   for type 'image':
#
#       file            basename of the scaled image file
#
#       path            absolute path to the scaled image. this file should be
#                       served to the user
#
#       fullsize_path   absolute path to the full-size image. if the full-size
#                       image is being displayed, this is the same as 'path'
#
#       image_type      'png' or 'jpeg'
#
#       mime            'image/png' or 'image/jpeg', suitable for the
#                       Content-Type header
#
#       (content)       binary image data. omitted with 'dont_open' option
#
#       length          bytelength of image data, suitable for use in the
#                       Content-Length header
#
#       mod_unix        UNIX timestamp of when the image was last modified.
#                       if 'generated' is true, this is the current time.
#                       if 'cached' is true, this is the modified date of the
#                       cache file. otherwise, this is the modified date of the
#                       image file itself
#
#       modified        like 'mod_unix' except in HTTP date format, suitable for
#                       use in the Last-Modified header
#
#       (cached)        true if the content being served was read from a cache
#                       file (opposite of 'generated')
#
#       (generated)     true if the content being served was just generated in
#                       order to fulfill this request (opposite of 'cached')
#
#       (cache_gen)     true if the content generated in order to fulfill this
#                       request was written to a cache file for later use. this
#                       can only be true if 'generated' is true
#
#   for type 'not found':
#
#       error           a human-readable error string. sensitive info is never
#                       included, so this may be shown to users
#
```

## path_for_image

```perl
my $path = $wiki->path_for_image('picture.jpg');
```

Returns the absolute path to a full-size image on the wiki.

## parse_image_name

```perl
my $image = $wiki->parse_image_name('200x150-picture@2x.jpg');
```

Parses an image name with optional dimensions and scale, returning the extracted
parts.

```
# Input
#
#   (width)x(height)-(filename without extension)@(scale)x.(extension)
#       250x250-some_pic@2x.png
#
#   (width)x(height)-(filename)
#       250x250-some_pic.png
#
#   (filename)
#       some_pic.png
#
# Result
#
#   name            fullsize image name without regard to the specified
#                   dimensions or scale, such as image.png
#
#   name_ne         same as 'name' except the extension is not included
#
#   ext             image filename extension, 'png', 'jpg' or 'jpeg'
#
#   full_name       image name with dimensions. if no dimensions were provided,
#                   this is the same as 'name'
#
#   full_name_ne    image name with dimensions but no extension. if no
#                   dimensions were provided, this is the same as 'name_ne'
#
#   scale_name      image name with dimensions and retina scale. if no retina
#                   scale was provided, this is the same as 'full_name'
#
#   scale_name_ne   image name with dimensions and retina scale but no
#                   extension. if no retina scale was provided, this is the same
#                   as 'full_name_ne'
#
#   r_width         "real" width without regard to the retina scale. if no
#                   dimensions were provided, this is zero
#
#   r_height        "real" height without regard to the retina scale. if no
#                   dimensions were provided, this is zero
#
#   retina          retina scale. if no retina scale was provided, this is zero
#                   (NOT one)
#
#   width           possibly scaled width. if no retina scale was provided, this
#                   is the same as 'r_width'
#
#   height          possibly scaled height. if no retina scale was provided,
#                   this is the same as 'r_height'
#
#   if the provided image name does not include dimensions,
#
#       width           == 0
#       height          == 0
#       r_width         == 0
#       r_height        == 0
#       full_name       == name
#       full_name_ne    == name_ne
#
#   if the provided image name does not include retina scale,
#
#       scale_name      == full_name
#       scale_name_ne   == full_name_ne
#       width           == r_width
#       height          == r_height
#       retina          == 0 (NOT 1)
#
```

## all_images

```perl
my @image_names = $wiki->all_images;
```

Returns a list of all image names on the wiki.

## get_images

```perl
my $images = $wiki->get_images;
```

Returns a filename-to-metadata hash reference of all images on the wiki.

## get_image

```perl
my $image_info = $wiki->get_image('picture.jpg');
```

Returns a hash reference of metadata for an image given its name.

# Models

These methods are for working with [models](../models.md) on the wiki.

## display_model

```perl
my $result = $wiki->display_model($model_name);
```

Displays a model.

## display_model_code

```perl
my $result = $wiki->display_model_code($model_name);
```

Displays the wiki source code for a model.

## model_named

```perl
my $model = $wiki->model_named('some.model');
```

Returns a [`Wikifier::Page`](page.md) object for a model associated with this
wiki.

## all_models

```perl
my @model_names = $wiki->all_models;
```

Returns a list of all model names on this wiki.

## path_for_model

```perl
my $path = $wiki->path_for_model('some.model');
```

Returns the absolute path to a model.

# Markdown

These methods are for managing wiki pages written in [Markdown](../markdown.md).

## convert_markdown

```perl
$wiki->convert_markdown($md_name);
```

Translates a Markdown file to the wikifier source language and writes it to a
page file.

## all_markdowns

```perl
my @md_names = $wiki->all_markdowns;
```

Returns a list of all Markdown files on this wiki.

# Revision

These methods are for wiki revision tracking.

## write_page

```perl
$wiki->write_page($page, $comment);
```

Writes a page, committing the changes to the wiki revision tracker. The page
content to write should be stored in the `{content}` property before calling
this. An optional comment may be provided.

## delete_page

```perl
$wiki->delete_page($page);
```

Deletes a page, committing the changes to the wiki revision tracker.

## move_page

```perl
$wiki->move_page($page, $new_name, $allow_overwrite);
```

Renames a page, committing the changes to the wiki revision tracker. If
`$allow_overwrite` is not true, the function fails when the target exists.
Returns error string on failure, nothing otherwise.

## rev_latest

```perl
my $rev = $wiki->rev_latest;
```

Fetches metadata for the latest revision in the wiki revision tracker.

__$rev__ - hash reference representing a revision
* __id__ - unique revision identifier
* __author__ - full name of the revision author
* __date__ - date of revision in an unspecified human-readable format
* __message__ - comment associated with the revision

## revs_matching_page

```perl
my @revs = $wiki->revs_matching_page($page);
```

Fetches metadata for all revisions matching a page in the wiki revision tracker.
Returns a list of revision metadata in the same format returned by
[`->rev_latest`](#rev_latest).

## diff_for_page

```perl
my $diff = $wiki->diff_for_page($page_or_name, $from, $to);
```

Fetches a diff for a page in the wiki, given two reference points in the wiki
revision tracker. On success, returns a string diff, otherwise nothing.

## rev_commit

```perl
$wiki->rev_commit(%opts);
```

Commits low-level changes to the wiki revision tracker.

__%opts__ - hash of options (all optional)
* __user__ - user info as returned by [`verify_login`](#verify_login), used for
  author of the revision
* __rm__ - array reference of files to remove
* __add__ - array reference of files to add
* __mv__ - hash reference of old-to-new files to move
* __message__ - comment for the revision
