# Wikifier::Wiki

`Wikifier::Wiki` is a programming interface for a file-based wiki site.

## Constructor

```perl
```

Creates an instance representing a wiki. This may be reused indefinitely.
Multiple instances may exist for the same wiki, such as in separate processes
or threads of a web server.

## opt

```perl
```

Fetches a wiki configuration option.

## verify_login

```perl
```

Verifies the credentials of a user defined in the private wiki configuration
file.

## display_error

```perl
```

Procedural function returns an error for any display method.

## unique_files_in_dir

```perl
```

Returns a list of filenames in a directory, ignoring files that appear more
than once due to symbolic links.

## file_contents

```perl
```

Slurps the entire contents of file. If `$binary` is true, the file is treated
as binary data; otherwise, it is read in UTF-8 mode.

# Pages

These methods are for managing pages in the wiki.

## display_page

```perl
```

Displays a page.

## display_page_code

```perl
```

Displays the wiki source code for a page.

## path_for_page

```perl
```

Returns the absolute path to a page given its name.

## page_named

```perl
```

Returns a [Wikifier::Page](page.md) object associated with this wiki.

## all_pages

```perl
```

Returns a list of all page names on the wiki.

## get_pages

```perl
```

Returns a filename-to-metadata hash reference about all the pages on the wiki.

## get_page

```perl
```

Returns a hash reference of metadata for a page given its name.

# Categories

These methods are for managing wiki page categories.

## display_cat_posts

```perl
```

Displays pages within a category in the style of blog posts.

## path_for_category

```perl
```

Returns the absolute path to a category given its name.

## cat_check_page

```perl
```

After parsing a page, this is used to update categories that the page belongs to
and remove it from ones it no longer does.

## cat_add_page

```perl
```

Adds a page to a category.

## cat_add_image

```perl
```

Adds a page to an image category.

## cat_get_pages

```perl
```

Fetches all the pages in a category.

## all_categories

```perl
```

Returns a list of all category names on the wiki.

# Images

These methods are for working with images on the wiki.

## display_image

```perl
```

Displays an image.

## path_for_image

```perl
```

Returns the absolute path to a full-size image on the wiki.

## parse_image_name

```perl
```

Parses an image name with optional dimensions and scale, returning the extracted
parts.

## all_images

```perl
```

Returns a list of all image names on the wiki.

## get_images

```perl
```

Returns a filename-to-metadata hash reference of all images on the wiki.

## get_image

```perl
```

Returns a hash reference of metadata for an image given its name.

# Models

These methods are for working with [models](../models.md) on the wiki.

## display_model

```perl
```

Displays a model.

## display_model_code

```perl
```

Displays the wiki source code for a model.

## model_named

```perl
```

Returns a [`Wikifier::Page`](page.md) object for a model associated with this
wiki.

## all_models

```perl
```

Returns a list of all model names on this wiki.

## path_for_model

```perl
```

Returns the absolute path to a model.

# Markdown

These methods are for managing wiki pages written in [Markdown](../markdown.md).

## convert_markdown

```perl
```

Translates a Markdown file to the wikifier source language and writes it to a
page file.

## all_markdowns

```perl
```

Returns a list of all Markdown files on this wiki.

# Revision

These methods are for wiki revision tracking.

## write_page

```perl
```

Writes a page, committing the changes to the wiki revision tracker.

## delete_page

```perl
```

Deletes a page, committing the changes to the wiki revision tracker.

## move_page

```perl
```

Renames a page, committing the changes to the wiki revision tracker.

## rev_latest

```perl
```

Fetches metadata for the latest revision in the wiki revision tracker.

## revs_matching_page

```perl
```

Fetches metadata for all revisions matching a page in the wiki revision tracker.

## diff_for_page

```perl
```

Fetches a diff for a page in the wiki, given two reference points in the wiki
revision tracker.

## rev_commit

```perl
```

Commits low-level changes to the wiki revision tracker.
