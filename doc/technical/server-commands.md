# wikiserver commands

This is the list of commands supported by the wikiserver.

# Authentication

These authentication commands are available to anonymous connections.

## wiki

Authenticates the connection for read access to a particular wiki.

```
C: ["wiki",{"config":true,"name":"mywiki","password":"secret"},3]
S: ["wiki",{"config":{"root":{"page":"/page","image":"/file"}}},3]
```

* __name__ - wiki name.
* __password__ - wiki password for read authentication in plain text.
* __config__ - _optional_, if true, the wiki configuration is returned.
  otherwise, a successful authentication has no reply.
  
`wiki` has no response unless __config__ is true.

## select

After authenticating for multiple wikis with the [`wiki`](#wiki) command,
`select` is used to switch between them without having to send the password
again.

```
S: ["select",{"name":"mywiki"},6]
```

* __name__ - wiki name.

Response

* __name__ - same wiki name, to verify a successful switch.

## login

Authenticates the connection for write access to a particular wiki.

* __username__ - username for write authentication.
* __password__ - password for write authentication in plain text.
* __session_id__ - _optional_,

Response
* __logged_in__ - true if successful.
* __conf__ - _deprecated_, wiki configuration.
* user metadata - any or none of these may be present
  * __name__ - user's full name.
  * __email__ - user's email address.

## resume

If a session ID was provided to the [`login`](#login) command, `resume` can be
used in place of `login` on subsequent connections, providing only the session
ID instead of sending the login credentials again.

The wikiserver may choose to deny the session ID due to old age or any other
reason, in which case the frontend should redirect the user to login again.

* __session_id__ - session identifier which was provided to [`login`](#login)
  when the user initially authenticated for write access.
  
A successful `resume` has no response.

# Read-required

These commands are available to connections which have authenticated for read
access.

## page

Returns the generated HTML and CSS content for a page as well as additional
metadata.

```
C: ["page",{"name":"welcome"},5]
S: ["page",{"content":"<!-- cached page dated Sun, 16 Apr 2017 16:52:33 GMT -->","type":"page","path":"/home/www/mywiki/pages/welcome.page","file":"welcome.page","fmt_title":"Welcome to My Wiki!","title":"Welcome to My Wiki!","mime":"text/html","cached":"1","mod_unix":"1492361553","name":"welcome","warnings":["Line 18:30: Page target 'about' does not exist"],"author":"John Doe","created":"1484537057","modified":"Sun, 16 Apr 2017 16:52:33 GMT"},5]
```

Response
* __type__ - type of response, one of `not found`, `redirect`, or `page`.
```
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
#                       if 'cache_gen' is true, this is the current time.
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
#                       viewing. this only ever occurs if the 'draft_ok' option
#                       was used; otherwise result would be of type 'not found'
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
```

## page_code

Returns the wiki source code of a page.

* __name__: page filename.
* __display_page__: _optional_, if `1`, also include the result of
  [`page`](#page) as the `display_page` key in the response. the page content is
  omitted. if `2`, also include the content.

Response
* __file__ - filename of the page, including extension.
* __path__ - absolute path to the page on the filesystem.
* __content__ - wiki source code for the page.
* __mime__ - `text/plain` (appropriate for Content-Type header)
* __type__ - `page_code`

## page_list

Returns metadata for all pages in the wiki, suitable for displaying a page
list.

* __sort__ - [how to sort](#sort-options) the page list.
    
Response
* __TODO__

## model_code

Returns the wiki source code of a model.

* __name__: model filename.
* __display_page__: _optional_, if `1`, also include the result of
  [`page`](#page) as the `display_page` key in the response. the model content
  is omitted. if `2`, also include the content.
  
Response
* __file__ - filename of the model, including extension.
* __path__ - absolute path to the model on the filesystem.
* __content__ - wiki source code for the model.
* __mime__ - `text/plain` (appropriate for Content-Type header)
* __type__ - `model_code`

## model_list

Returns metadata for all models in the wiki, suitable for displaying a model
list.

* __sort__ - [how to sort](#sort-options) the model list.
    
Response
* __TODO__

## image

Returns the metadata for an image, including an absolute path on the filesystem.
The image data itself is NOT transmitted over the wikiserver transport; instead,
the frontend should serve the image file directly.

```
C: ["image",{"name":"200x200-the_crew@2x.jpg"},22]
S: ["image",{"file":"the_crew.jpg","cached":"1","mime":"image/jpeg","length":"133566","cache_path":"/home/www/mywiki/cache/400x400-the_crew.jpg","path":"/home/www/mywiki/cache/400x400-the_crew.jpg","type":"image","image_type":"jpeg","modified":"Sun, 16 Apr 2017 16:52:32 GMT","mod_unix":"1492361552","fullsize_path":"/home/www/mywiki/images/the_crew.jpg"},22]
```

* __name__ - image filename.
* __width__ - _optional_, desired image width.
* __height__ - _optional_, desired image height.

Response
```
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

## image_list

Returns metadata for all images in the wiki, suitable for displaying an image
list.

* __sort__ - [how to sort](#sort-options) the image list.
    
Response
* __TODO__

## cat_posts

Returns a collection of pages which belong to a particular category, including
their metadata, generated HTML, and generated CSS contents. This is suitable for
displaying several related pages at once. The results may be paginated.

## cat_list

Returns metadata for all categories in the wiki, suitable for displaying a
category list.

* __sort__ - [how to sort](#sort-options) the category list.

    
Response
* __TODO__

# Write-required

These commands are available to connections which have authenticated for write
access.

## page_save

Writes wiki source code to a page file. The page file may or may not already
exist. The changes are committed to the wiki revision tracker. The page
is immediately regenerated upon save.

## page_del

Deletes a page file. The changes are committed to the wiki revision tracker.

## page_move

Renames a page file. The changes are committed to the wiki revision tracker.

## model_save

Writes wiki source code to a model file. The model file may or may not already
exist. The changes are committed to the wiki revision tracker.

## model_del

Deletes a model file. The changes are committed to the wiki revision tracker.

## model_move

Renames a model file. The changes are committed to the wiki revision tracker.

## cat_del

Deletes a category. The changes are committed to the wiki revision tracker.

## ping

Used by frontends to verify that a session is still active. Also, notifications
from the wikiserver may be delivered in reply.

# Sort options

* `a+` - alphabetically by title ascending (a-z)
* `a-` - alphabetically by title descending (z-a)
* `c+` - by creation time ascending (oldest first)
* `c-` - by creation time descending (recent first)
* `d+` - by dimensional area ascending (images only)
* `d-` - by dimensional area descending (images only)
* `m+` - by modification time ascending (oldest first)
* `m-` - by modification time descending (recent first)
* `u+` - alphabetically by author ascending (a-z)
* `u-` - alphabetically by author descending (z-a)
