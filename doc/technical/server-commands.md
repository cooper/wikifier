# wikiserver commands

This is the list of commands supported by the wikiserver.

# Authentication

These authentication commands are available to anonymous connections.

## wiki

Authenticates the connection for read access to a particular wiki.

## select

After authenticating for multiple wikis with the [`wiki`](#wiki) command,
`select` is used to switch between them without having to send the password
again.

## login

Authenticates the connection for write access to a particular wiki.

## resume

If a session ID was provided to the [`login`](#login) command, `resume` can be
used in place of `login` on subsequent connections, providing only the session
ID instead of sending the login credentials again.

The wikiserver may choose to deny the session ID due to old age or any other
reason, in which case the frontend should redirect the user to login again.

# Read-required

These commands are available to connections which have authenticated for read
access.

## page

Returns the generated HTML and CSS content for a page as well as additional
metadata.

## page_code

Returns the wiki source code of a page.

## page_list

Returns metadata for all pages in the wiki, suitable for displaying a page
list.

## model_code

Returns the wiki source code of a model.

## model_list

Returns metadata for all models in the wiki, suitable for displaying a model
list.

## image

Returns the metadata for an image, including an absolute path on the filesystem.
The image data itself is NOT transmitted over the wikiserver transport; instead,
the frontend should serve the image file directly.

## image_list

Returns metadata for all images in the wiki, suitable for displaying an image
list.

## cat_posts

Returns a collection of pages which belong to a particular category, including
their metadata, generated HTML, and generated CSS contents. This is suitable for
displaying several related pages at once. The results may be paginated.

## cat_list

Returns metadata for all categories in the wiki, suitable for displaying a
category list.

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
