#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# The Wikifier is a simple wiki language parser. It merely converts wiki language to HTML.
# Wikifier::Wiki, on the other hand, provides a full wiki management mechanism. It
# features image sizing, page and image caching, and more.
#
# The Wikifier and Wikifier::Page can operate as only a parser without this class.
# This is useful if you wish to implement your own image resizing and caching methods
# or if you don't feel that these features are necessary.
#
package Wikifier::Wiki;

use warnings;
use strict;
use feature qw(switch);

use Wikifier;

# Wiki options:
#
# Wikifier::Wiki specific options:
#
#   enable_page_caching: true if you wish to enable wiki page caching.
#   enable_image_sizing: true if you wish to enable image sizing and caching.
#   
# Wikifier::Page wiki options:
#
#   name:               simple name of the wiki, such as "NoTrollPlzNet Library."
#   variables:          a hash reference of global wiki variables.
#
#   HTTP address roots.
#
#   image_root:         HTTP address of file directory, such as http://example.com/files .
#   wiki_root:          HTTP address of wiki root (typically relative to /)
#   external_root:      HTTP address of external wiki root (defaults to English Wikipedia)
#
#   Directories on the filesystem (ABSOLUTE DIRECTORIES, not relative)
#
#   image_directory:    local directory containing wiki media files and images.
#   cache_directory:    local directory for storing cached pages and images. (writable)
#
#   The following are provided automatically by Wikifier::Wiki:
#
#   size_images:        either 'javascript' or 'server' (see below)
#   image_sizer:        a code reference returning URL to resized image (see below)
#   rounding:           'normal', 'up', or 'down' for how dimensions should be rounded.
#

# create a new wiki object.
sub new {
    my ($class, %opts) = @_;
    return \%opts, $class;
}


# display() displays a wiki page or resource.
#
# takes a page name such as:
#   Some Page
#   some_page
#
# takes an image in the form of:
#   image/[imagename].png
#   image/[width]x[height]-[imagename].png
# For example:
#   image/flower.png
#   image/400x200-flower.png
#
# Returns a hash reference of results for display.
#   type: either 'page', 'image', or 'not found'
#   
#   if the type is 'page'
#       content:    the generated wiki HTML.
#       cached:     true if the content was fetched from cache.
#       generated:  true if the content was just generated.
#       cache_gen:  true if the content was generated and has been cached.
#
#   if the type is 'image'
#       image_type: either 'jpg' or 'png'
#       image_data: the image binary data
#       image_head: HTTP content type, such as 'image/png' or 'image/jpeg'
#
#   if the type is 'not found'
#       no other values are set.
#
sub display {
    my ($wiki, $page_name, $result) = (shift, shift, {});
    
    # it's an image.
    if ($page_name =~ m|^image/(.+)$|) {
        my ($image_name, $width, $height, $file_name) = $1;
        
        # height and width were given, so it's a resized image.
        if ($image_name =~ m/^(\d+)x(\d+)-(.+)$/) {
            ($width, $height, $file_name) = ($1, $2, $3);
        }
        
        # only file name was given, so the full sized image is desired.
        else {
            ($width, $height, $file_name) = (0, 0, $image_name);
        }
    
        $wiki->display_image($result, $file_name, $width, $height);
    }
    
    # it's a wiki page.
    else {
        $wiki->display_page($result, $page_name);
    }
    
    return $result;
}

# displays an image of the supplied dimensions.
sub display_image {
    my ($wiki, $result, $file_name, $width, $height) = @_;
}

# displays a page.
sub display_page {
    my ($wiki, $result, $page_name) = @_;
}

1
