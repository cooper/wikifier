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

use GD;

use Wikifier;

# Wiki options:
#
# Wikifier::Wiki specific options:
#
#   enable_page_caching: true if you wish to enable wiki page caching.
#   enable_image_sizing: true if you wish to enable image sizing and caching.
#                        note: if you are using image sizing, the 'image_root' option
#                        below will be ignored as the Wikifier will generate image URLs.
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
#   page_directory:     local directory containing page files.
#   image_directory:    local directory containing wiki images.
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
    my $wiki = bless \%opts, $class;
    
    # default options.
    $wiki->{rounding}    = 'up';
    $wiki->{size_images} = 'server';
    
    # image sizer callback.
    $wiki->{image_sizer} = sub {
        my %img = @_;
        return ""; # TODO
    };
    
    return $wiki;
}

# returns a wiki option.
sub opt {
    my ($wiki, $opt) = @_;
    return $wiki->{$opt} if exists $wiki->{$opt};
    return $Wikifier::Page::wiki_defaults{$opt};
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
#   if the type is 'page':
#       cached:     true if the content was fetched from cache.
#       generated:  true if the content was just generated.
#       cache_gen:  true if the content was generated and has been cached.
#       page:       the Wikifier::Page object representing the page. (if generated)
#
#   if the type is 'image':
#       image_type: either 'jpeg' or 'png'
#       image_data: the image binary data (synonym to 'content')
#
#   for anything except errors, the following will be set:
#       file:       the filename of the resource (not path) ex 'hello.png' or 'some.page'
#       path:       the full path of the resource ex '/srv/www/example.com/hello.png'
#       mime:       the MIME type, such as 'text/html' or 'image/png'
#       modified:   the last modified date of the resource in HTTP date format
#       length:     the length of the resource in octets
#       etag:       an HTTP etag for the resource in the form of an md5 string
#       content:    the page content or binary data to be sent to the client
#
#   if the type is 'not found'
#       error: a string error.
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

# displays a page.
sub display_page {
    my ($wiki, $result, $page_name) = @_;
    
    # replace spaces with _ and lowercase.
    $page_name =~ s/\s/_/g;
    $page_name = lc $page_name;
    
    # append .page if it isn't already there.
    if (substr($page_name, -1, 5) ne 'page') {
        $page_name .= q(.page);
    }
    
    # determine the page file name.
    my $file       = $wiki->opt('page_directory') .q(/).$page_name;
    my $cache_file = $wiki->opt('cache_directory').q(/).$page_name.q(.cache);
    
    $result->{file} = $page_name;
    $result->{path} = $file;
    
    # file does not exist.
    if (!-f $file) {
        $result->{error} = "File '$file' not found";
        $result->{type}  = 'not found';
        return;
    }
    
    # caching is enabled, so let's check for a cached copy.
    
    if ($wiki->opt('enable_page_caching') && -f $cache_file) {
        my ($page_modify, $cache_modify) = ((stat $file)[9], (stat $cache_file)[9]);
    
        # the page's file is more recent than the cache file.
        if ($page_modify > $cache_modify) {
        
            # discard the outdated cached copy.
            unlink $cache_file;
        
        }
        
        # the cached file is newer, so use it.
        else {
            my $time = scalar localtime $cache_modify;
            $result->{type}     = 'page';
            $result->{content}  = "<!-- cached page dated $time -->\n";
            
            # fetch the title.
            my $cache_data = file_contents($cache_file);
            my @data = split /\n/, $cache_data;
            
            $result->{title}    = shift @data;
            $result->{content} .= join "\n", @data;
            $result->{cached}   = 1;
            return;
        }
        
    }
    
    # cache was not used. generate a new copy.
    my $page = $result->{page} = Wikifier::Page->new(
        file => $file,
        wiki => $wiki
    );
    
    # parse the page.
    $page->parse();
    
    # generate the HTML.
    $result->{type}      = 'page';
    $result->{content}   = $page->html();
    $result->{title}     = $page->get('page.title');
    $result->{generated} = 1;
    
    # caching is enabled, so let's save this for later.
    if ($wiki->opt('enable_page_caching')) {
    
        open my $fh, '>', $cache_file;
        print {$fh} $result->{title}, "\n";
        print {$fh} $result->{content};
        close $fh;
        
        $result->{cache_gen} = 1;
    }
    
}

# displays an image of the supplied dimensions.
sub display_image {
    my ($wiki, $result, $image_name, $width, $height) = @_;

    # check if the file exists.
    my $file = $wiki->opt('image_directory').q(/).$image_name;
    if (!-f $file) {
        $result->{type}  = 'not found';
        $result->{error} = 'image does not exist';
        return;
    }
    
    # stat for full-size image.
    my @stat = $stat $file;
    
    # image name and full path.
    $result->{file} = $image_name;
    $result->{path} = $file;
    
    # determine image short name, extension, and mime type.
    $image_name      =~ m/(.+)\.(.+)/;
    my ($name, $ext) = ($1, $2);
    my $mime         = $ext eq 'png' ? 'image/png' : 'image/jpeg';
    
    # if no width or height are specified,
    # display the full-sized version of the image.
    if (!$width && !$height) {
        $result->{type}         = 'image';
        $result->{image_type}   = $ext eq 'jpg' || $ext eq 'jpeg' ? 'jpeg' : 'png';
        $result->{mime}         = $mime;
        $result->{content}      = file_contents($file, 1);
        $result->{modified}     = time2str($stat[9]);
        $result->{length}       = $stat[7];
        $result->{etag}         = q(").md5($image_name.$result->{modified}).q(");
    }
    
}

# returns entire contents of a file.
sub file_contents {
    my ($file, $binary) = @_;
    local $/ = undef;
    open my $fh, '<', $file;
    binmode $fh if $binary;
    my $content = <$fh>;
    close $fh;
    return $content;
}

1
