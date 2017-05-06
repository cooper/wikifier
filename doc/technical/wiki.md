# Wikifier::Wiki

`Wikifier::Wiki` is a programming interface for a file-based wiki site.

## Constructor

## opt

## verify_login

## display_error

## unique_files_in_dir

## file_contents

# Pages

These methods are for managing pages in the wiki.

## path_for_page

## page_named

## display_page

## display_page_code

## all_pages

## get_pages

## get_page

# Categories

These methods are for managing wiki page categories.

## path_for_category

## display_cat_posts

## cat_check_page

## cat_add_page

## cat_add_image

## cat_get_pages

## cat_should_delete

## all_categories

# Images

These methods are for working with images on the wiki.

## path_for_image

## display_image

## parse_image_name

## all_images

## get_images

## get_image

# Models

These methods are for working with [models](../models.md) on the wiki.

## model_named

## display_model

## display_model_code

## all_models

## path_for_model

# Markdown

These methods are for managing wiki pages written in [Markdown](../markdown.md).

## convert_markdown

## all_markdowns

# Revision

These methods are for wiki revision tracking.

## write_page

## delete_page

## move_page

## rev_latest

## revs_matching_page

## diff_for_page

## rev_commit
