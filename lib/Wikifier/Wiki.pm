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
use HTTP::Date 'time2str';
use Digest::MD5 'md5_hex';

use Wikifier;

# Wiki options:
#
# Wikifier::Wiki specific options:
#
#   enable_page_caching:    true if you wish to enable wiki page caching.
#
#   enable_image_sizing:    true if you wish to enable image sizing.
#                           note: if you are using image sizing, the 'image_root' option
#                           below will be ignored as the Wikifier will generate image URLs.
#
#   enable_image_caching:   true if you wish for sized images to be cached.
#
#   force_image_type:       you can specify 'jpeg' or 'png' if you prefer for images to
#                           always be generated in one of these formats. by default, PNG
#                           images generate PNG images, and JPEG images generate JPEG
#                           images compressed with the highest possible quality.
#
#   force_jpeg_quality:     if you set 'force_image_type' to 'jpeg', this option forces
#                           JPEG images to be compressed with this quality. (range: 1-100)
#
#   enable_retina_display:  enable if you wish to support high-resolution image generation
#                           for clear images on Apple's Retina display technology.
#
#   restrict_image_size:    restrict image generation to dimensions used in the wiki.
#                           
#   
# Wikifier::Page wiki options:
#
#   name:               simple name of the wiki, such as "NoTrollPlzNet Library."
#   variables:          a hash reference of global wiki variables.
#
#   HTTP address roots.
#
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
#   image_root:         HTTP address of file directory, such as http://example.com/files .
#   image_dimension_calculator: code returning dimensions of a resized image
#

# create a new wiki object.
sub new {
    my ($class, %opts) = @_;
    my $wiki = bless \%opts, $class;
    
    # default options.
    $wiki->{rounding}    = 'up';
    $wiki->{size_images} = 'server';
    $wiki->{image_root}  = $wiki->{wiki_root}.q(/image);
    
    # image sizer callback.
    $wiki->{image_sizer} = sub {
        my %img = @_;
        
        # full-sized image.
        if (!$wiki->opt('enable_image_sizing') || !$img{width} || !$img{height} ||
            $img{width} eq 'auto' || $img{height} eq 'auto') {
            
            return $wiki->{image_root}.q(/).$img{file};
        }
        
        # scaled image.
        return $wiki->{image_root}.q(/).$img{width}.q(x).$img{height}.q(-).$img{file};
        
    };
    
    # we use GD for image size finding because it is already a dependency of WiWiki.
    $wiki->{image_dimension_calculator} = sub {
        my %img = @_;
        
        my $file = $img{page}->wiki_info('image_directory').q(/).$img{file};
        
        # find the image size.
        my $full_image      = GD::Image->new($file) or return (0, 0);
        my ($big_w, $big_h) = $full_image->getBounds();
        undef $full_image;
        
        # call the default handler with these dimensions.
        my ($w, $h) = Wikifier::Page::_default_calculator(
            %img,
            big_width  => $big_w,
            big_height => $big_h
        );
        
        # store this as accepted dimensions.
        $wiki->{allowed_dimensions}{$img{file}}{$w.q(x).$h} = 1;
        
        return ($w, $h);
    
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
#       cached:     true if the image was fetched from cache.
#       generated:  true if the image was just generated.
#       cache_gen:  true if the image was generated and has been cached.
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
    
    # file does not exist.
    if (!-f $file) {
        $result->{error} = "File '$file' not found";
        $result->{type}  = 'not found';
        return;
    }
    
    # set path, file, and meme type.
    $result->{file} = $page_name;
    $result->{path} = $file;
    $result->{mime} = 'text/html';
    
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
            my $time = time2str($cache_modify);
            $result->{type}     = 'page';
            $result->{content}  = "<!-- cached page dated $time -->\n";
            
            # fetch the title.
            my $cache_data = file_contents($cache_file);
            my @data = split /\n/, $cache_data;
            
            # set HTTP data.
            $result->{title}    = shift @data;
            $result->{content} .= join "\n", @data;
            $result->{cached}   = 1;
            $result->{modified} = $time;
            $result->{length}   = length $result->{content};
            
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
    
    # generate the HTML and headers.
    $result->{type}      = 'page';
    $result->{content}   = $page->html();
    $result->{length}    = length $result->{content};
    $result->{title}     = $page->get('page.title');
    $result->{generated} = 1;
    $result->{modified}  = time2str(time);
    
    # caching is enabled, so let's save this for later.
    if ($wiki->opt('enable_page_caching')) {
    
        open my $fh, '>', $cache_file;
        print {$fh} $result->{title}, "\n";
        print {$fh} $result->{content};
        close $fh;
        
        # overwrite modified date to actual.
        $result->{modified}  = time2str((stat $cache_file)[9]);
        
        $result->{cache_gen} = 1;
    }
    
}

# displays an image of the supplied dimensions.
sub display_image {
    my ($wiki, $result, $image_name, $width, $height) = @_;
    my ($retina, $scaled_w, $scaled_h) = (0, $width, $height);
    
    # retina image. double its dimensions.
    if ($wiki->opt('enable_retina_display') && $image_name =~ m/^(.+)[\@\_]2x(.+?)$/) {
        $image_name = $1.$2;
        $scaled_w   = $width;
        $scaled_h   = $height;
        $width     *= 2;
        $height    *= 2;
        $retina     = 1;
    }

    # check if the file exists.
    my $file = $wiki->opt('image_directory').q(/).$image_name;
    if (!-f $file) {
        $result->{type}  = 'not found';
        $result->{error} = 'image does not exist';
        return;
    }
    
    # stat for full-size image.
    my @stat = stat $file;
    
    # image name and full path.
    $result->{type} = 'image';
    $result->{file} = $image_name;
    $result->{path} = $file;
    
    # determine image short name, extension, and mime type.
    $image_name      =~ m/(.+)\.(.+)/;
    my ($name, $ext) = ($1, $2);
    my $mime         = $ext eq 'png' ? 'image/png' : 'image/jpeg';

    # image type and mime type.    
    $result->{image_type}   = $ext eq 'jpg' || $ext eq 'jpeg' ? 'jpeg' : 'png';
    $result->{mime}         = $mime;
    
    # if no width or height are specified,
    # display the full-sized version of the image.
    if (!$retina and !$width || !$height) {
        $result->{content}      = file_contents($file, 1);
        $result->{modified}     = time2str($stat[9]);
        $result->{length}       = $stat[7];
        $result->{etag}         = q(").md5_hex($image_name.$result->{modified}).q(");
        return;
    }
    
    # this is a smaller copy.
    
    # at this point, if we have no width or height, we must
    # check the dimensions of the original image.
    if (!$width || !$height) {
        my $full_image      = GD::Image->new($file) or return (0, 0);
        ($width, $height)   = $full_image->getBounds();
        undef $full_image;
        
        # if retina, double.
        if ($retina) {
            $width  *= 2;
            $height *= 2;
        }
        
    }
    
    my $full_name = $width.q(x).$height.q(-).$image_name;
    my $cache_file = $wiki->opt('cache_directory').q(/).$full_name;
    
    # if caching is enabled, check if this exists in cache.
    if ($wiki->opt('enable_image_caching') && -f $cache_file) {
        my ($image_modify, $cache_modify) = ((stat $file)[9], (stat $cache_file)[9]);
        
        # the image's file is more recent than the cache file.
        if ($image_modify > $cache_modify) {
        
            # discard the outdated cached copy.
            unlink $cache_file;
        
        }
        
        # the cached file is newer, so use it.
        else {
            
            # set HTTP data.
            $result->{cached}       = 1;
            $result->{content}      = file_contents($cache_file, 1);
            $result->{modified}     = time2str($cache_modify);
            $result->{length}       = length $result->{content};
            $result->{etag}         = q(").md5_hex($image_name.$result->{modified}).q(");
            
            return;
        }
        
    }
    
    # if image generation is disabled, we must supply the full-sized image data.
    if (!$wiki->opt('enable_image_sizing')) {
        return $wiki->display_image($result, $image_name, 0, 0);
    }
        
    # we have no cached copy. an image must be generated.
    
    
    # if we are restricting to only sizes used in the wiki, check.
    if ($wiki->opt('restrict_image_size')) {
        if (!$wiki->{allowed_dimensions}{$image_name}{$scaled_w.q(x).$scaled_h}) {
            $result->{type}  = 'not found';
            $result->{error} = 'invalid image size.';
            return;
        }
    }
    
    # otherwise, ensure that the images aren't enormous.
    else {
        if ($width > 1500 || $height > 1500) {
            $result->{type}  = 'not found';
            $result->{error} = 'that is way bigger than an image on a wiki should be.';
            return;
        }
    }
    
    
    GD::Image->trueColor(1);
    my $full_image = GD::Image->new($file);

    # create resized image.
    my $image = GD::Image->new($width, $height);
    $image->saveAlpha(1);
    $image->alphaBlending(0);
    $image->copyResampled($full_image,
        0, 0,
        0, 0,
        $width, $height,
        $full_image->getBounds
    );
    
    # create JPEG or PNG data.
    my $use = $wiki->opt('force_image_type') || $result->{image_type};
    if ($use eq 'jpeg') {
        my $compression = $wiki->opt('force_jpeg_quality') || 100;
        $result->{content} = $image->jpeg($compression);
    }
    else {
        $image->saveAlpha(1);
        $image->alphaBlending(0);
        $result->{content} = $image->png();
    }

    $result->{generated}    = 1;
    $result->{modified}     = time2str(time);
    $result->{length}       = length $result->{content};
    $result->{etag}         = q(").md5_hex($image_name.$result->{modified}).q(");
    
    # caching is enabled, so let's save this for later.
    if ($wiki->opt('enable_image_caching')) {
    
        open my $fh, '>', $cache_file;
        print {$fh} $result->{content};
        close $fh;
        
        # overwrite modified date to actual.
        $result->{modified}  = time2str((stat $cache_file)[9]);
        $result->{cache_gen} = 1;
        $result->{etag}      = q(").md5_hex($image_name.$result->{modified}).q(");
        
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
