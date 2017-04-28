# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Wiki;

use warnings;
use strict;
use 5.010;

use GD;                             # image generation
use HTTP::Date qw(time2str);        # HTTP date formatting
use File::Spec ();                  # simplifying symlinks
use List::Util qw(max);
use Wikifier::Utilities qw(L Lindent align back hash_maybe);
use File::Basename qw(basename);
use JSON::XS ();

my $json = JSON::XS->new->pretty->convert_blessed;

##############
### IMAGES ###
##############

# Displays an image of the supplied dimensions.
#
# Input
#
#   $image_name     filename string or array ref of [ filename, width, height ]
#                   1) image.png                    full-size
#                   2) 123x456-image.png            scaled
#                   3) 123x456-image.png            scaled with retina
#                   4) [ 'image.png', 0,   0   ]    full-size
#                   5) [ 'image.png', 123, 456 ]    scaled
#                   6) [ 'image.png', 123, 0   ]    scaled with one dimension
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
sub display_image {
    my $name = ref $_[1] ? $_[1][0] : $_[1];
    Lindent "($name)";
        my $result = _display_image(@_);
    back;
    return $result;
}
sub _display_image {
    my ($wiki, $image_name, %opts) = @_;
    my $result = {};

    # if $image_name is an array ref, it's [ name, width, height ]
    # if both dimensions are 0, parse the image name normally
    if (ref $image_name eq 'ARRAY') {
        my ($name, $w, $h) = @$image_name;
        $image_name = "${w}x${h}-$name";
        $image_name = $name if !$w && !$h;
    }

    # parse the image name.
    my $image = $wiki->parse_image_name($image_name);
    return display_error($image->{error})
        if $image->{error};
        
    # check if the file exists.
    $image_name = $image->{name};
    my $big_path = $wiki->path_for_image($image_name);
    return display_error('Image does not exist.')
        if !-f $big_path;

    my $width   = $image->{width};
    my $height  = $image->{height};
    my @stat    = stat $big_path;

    # image name and full path.
    $result->{type} = 'image';
    $result->{path} = $result->{fullsize_path} = $big_path;
    $result->{file} = basename($result->{path});

    # image type and mime type.
    $result->{image_type} = $image->{ext} eq 'jpg' ||
                            $image->{ext} eq 'jpeg' ? 'jpeg' : 'png';
    $result->{mime} = $image->{ext} eq 'png' ? 'image/png' : 'image/jpeg';

    # if image caching is disabled or both dimensions are missing,
    # display the full-size version of the image.
    return $wiki->get_image_full_size($image, $result, \@stat, \%opts)
        if !$wiki->opt('image.enable.cache') || $width + $height == 0;

    # if one dimension is missing, calculate it.
    if (!$width || !$height) {
        ($width, $height) = $wiki->opt('image.calc',
            file   => $image_name,
            height => $height,
            width  => $width,
            wiki   => $wiki
        );
        
        # if the dimension calculator failed, fall back to the full-size image.
        return $wiki->get_image_full_size($image, $result, \@stat, \%opts)
            if !$width;
        
        # display the image with the calculated dimensions.
        return $wiki->_display_image([ $image_name, $width, $height ], %opts);
    }
    
    #============================#
    #=== Retina scale support ===#
    #============================#

    # this is not a retina request, but retina is enabled, and so is
    # pregeneration. therefore, we will call ->generate_image() in order to
    # pregenerate a retina version. this only happens if gen_override is true
    # (pregenration request, not real request from user).
    my $retina = $wiki->opt('image.enable.retina');
    if (!$image->{retina} && $opts{gen_override} && $retina) {
        my $max_scale = max 0, grep {
            s/^\s*//;           # ignore whitespace before
            s/\s*$//;           # ignore whitespace after
            !m/\D/ && $_ != 1;  # ignore non-digits and scale 1
        } split /,/, $retina;
        foreach (2..$max_scale) {
            my $retina_file = "$$image{full_name_ne}\@${_}x.$$image{ext}";
            $wiki->display_image($retina_file,
                dont_open    => 1,
                gen_override => 1
            );
        }
    }

    #=========================#
    #=== Find cached image ===#
    #=========================#

    # if caching is enabled, check if this exists in cache.
    my $cache_file = $wiki->opt('dir.cache').'/'.$image->{full_name};
    if ($wiki->opt('image.enable.cache') && -f $cache_file) {
        $result = $wiki->get_image_cache(
            $image, $result, $stat[9], $cache_file, \%opts);
        return $result if $result->{cached};
    }

    #======================#
    #=== Generate image ===#
    #======================#

    # we are not allowed to generate
    if ($wiki->opt('image.enable.restriction') && !$opts{gen_override}) {
        my $dimension_str = "$$image{width}x$$image{height}";
        return display_error("Image does not exist at $dimension_str.");
    }

    # generate the image
    my $err = $wiki->generate_image($image, $result);
    return $err if $err;

    # the generator says to use the full-size image.
    return $wiki->get_image_full_size($image, $result, \@stat, \%opts)
        if delete $result->{use_fullsize};

    delete $result->{content} if $opts{dont_open};
    return $result;
}

# get full size version of image
sub get_image_full_size {
    my ($wiki, $image, $result, $stat, $opts) = @_;

    # only include the content if dont_open is false
    $result->{content} = file_contents($result->{fullsize_path}, 1)
        unless $opts->{dont_open};

    $result->{modified}     = time2str($stat->[9]);
    $result->{mod_unix}     = $stat->[9];
    $result->{length}       = $stat->[7];

    return $result;
}

# get image from cache
sub get_image_cache {
    my ($wiki, $image, $result, $image_modify, $cache_file, $opts) = @_;
    my $cache_modify = (stat $cache_file)[9];

    # if the image's file is more recent than the cache file,
    # discard the outdated cached copy.
    if ($image_modify > $cache_modify) {
        unlink $cache_file;
        return $result;
    }

    # the cached file is newer, so use it.

    # only include the content if dont_open is false
    $result->{content} = file_contents($cache_file, 1)
        unless $opts->{dont_open};

    $result->{path}         = $cache_file;
    $result->{file}         = basename($cache_file);
    $result->{cached}       = 1;
    $result->{modified}     = time2str($cache_modify);
    $result->{mod_unix}     = $cache_modify;
    $result->{length}       = -s $cache_file;

    # symlink scaled version if necessary.
    $wiki->symlink_scaled_image($image) if $image->{retina};

    return $result;
}

# parse an image name such as:
#
#   250x250-some_pic.png
#   250x250-some_pic@2x.png
#   some_pic.png
#
sub parse_image_name {
    my ($wiki, $image_name) = @_;
    my ($width, $height) = (0, 0);

    # height and width were given, so it's a resized image.
    if ($image_name =~ m/^(\d+)x(\d+)-(.+)$/) {
        ($width, $height, $image_name) = ($1, $2, $3);
    }

    # split image parts.
    my ($image_wo_ext, $image_ext) = ($image_name =~ m/^(.+)\.(.+?)$/);

    # if this is a retina request; calculate 2x scaling.
    my ($real_width, $real_height) = ($width, $height);
    my $retina_request;
    if ($image_wo_ext =~ m/^(.+)\@(\d+)x$/) {
        $image_wo_ext   = $1;
        $retina_request = $2;
        $image_name     = "$1.$image_ext";
        $width  *= $retina_request;
        $height *= $retina_request;
    }

    my $full_name    = $image_name;
    my $full_name_ne = $image_wo_ext;
   $full_name    = "${width}x${height}-${image_name}"   if $width || $height;
   $full_name_ne = "${width}x${height}-${image_wo_ext}" if $width || $height;

    return {
        name            => $image_name,     # name;     e.g. image.png
        name_ne         => $image_wo_ext,   # name;     e.g. image
        ext             => $image_ext,      # extension e.g. png
        full_name       => $full_name,      # full name e.g. 123x456-image.png
        full_name_ne    => $full_name_ne,   # full name e.g. 123x456-image
        width           => $width,          # possibly scaled width
        height          => $height,         # possibly scaled height
        r_width         => $real_width,     # width without scaling
        r_height        => $real_height,    # height without scaling
        retina          => $retina_request  # retina scale  e.g. 2
    };
}

# generate an image of a certain size.
# returns error on fail, nothing on success
sub generate_image {
    my ($wiki, $image, $result) = @_;

    # an error occurred.
    return display_error($image->{error})
        if $image->{error};

    # if we are restricting to only sizes used in the wiki, check.
    my ($width, $height, $r_width, $r_height) =
        @$image{ qw(width height r_width r_height) };

    # create GD instance with this full size image.
    GD::Image->trueColor(1);
    my $full_image = GD::Image->new($result->{fullsize_path});
    return display_error("Couldn't handle image $$result{fullsize_path}")
        if !$full_image;
    my ($fi_width, $fi_height) = $full_image->getBounds();

    # the request is to generate an image the same or larger than the original.
    if ($width >= $fi_width && $height >= $fi_height) {
        $result->{use_fullsize} = 1;
        L align(
            'Skip',
            "${width}x${height} >= original ${fi_width}x${fi_height}"
        );

        # symlink to the full-size image.
        $image->{full_name} = $image->{name};
        $wiki->symlink_scaled_image($image) if $image->{retina};

        return; # success
    }

    # create resized image.
    my $sized_image = GD::Image->new($width, $height);
    return display_error("Couldn't create an empty image")
        if !$sized_image;
    $sized_image->saveAlpha(1);
    $sized_image->alphaBlending(0);
    $sized_image->copyResampled($full_image,
        0, 0,
        0, 0,
        $width, $height,
        ($fi_width, $fi_height)
    );

    # create JPEG
    my $use = $wiki->opt('image.type') || $result->{image_type};
    if ($use eq 'jpeg') {
        my $compression = $wiki->opt('image.quality') || 100;
        $result->{content} = $sized_image->jpeg($compression);
    }

    # create PNG
    else {
        $sized_image->saveAlpha(1);
        $sized_image->alphaBlending(0);
        $result->{content} = $sized_image->png();
    }

    $result->{generated}    = 1;
    $result->{modified}     = time2str(time);
    $result->{mod_unix}     = time;
    $result->{length}       = length $result->{content};

    # caching is enabled, so let's save this for later.
    my $cache_file = $result->{cache_path};
    if ($wiki->opt('image.enable.cache')) {
        
        open my $fh, '>', $cache_file
            or return display_error('Could not write image cache file');
        binmode $fh, ':raw';
        print {$fh} $result->{content};
        close $fh;

        # overwrite modified date to actual.
        my $modified = (stat $cache_file)[9];
        $result->{path}       = $cache_file;
        $result->{file}       = basename($cache_file);
        $result->{modified}   = time2str($modified);
        $result->{mod_unix}   = $modified;
        $result->{cache_gen}  = 1;

        # if this image is available in more than 1 scale, symlink.
        $wiki->symlink_scaled_image($image) if $image->{retina};
    }

    L align(
        'Generate',
        "${width}x${height}" .
        ($image->{retina} ? " (\@$$image{retina}x)" : '')
    );
    return; # success
}

# symlink an image to its scaled version
sub symlink_scaled_image {
    my ($wiki, $image) = @_;
    return unless $image->{retina};
    
    # retina path: file-123x456@2x.png
    my $scale_path = sprintf '%s/%dx%d-%s@%dx.%s',
        $wiki->opt('dir.cache'),
        $image->{r_width},
        $image->{r_height},
        $image->{name_ne},
        $image->{retina},
        $image->{ext};
    symlink $image->{full_name}, $scale_path
        unless -e $scale_path;

    # normal path: file-246x912.png
    # usually this is the image we are symlinking to above,
    # but if it doesn't exist, it is likely because {full_name}
    # is the full-size image.
    $scale_path = sprintf '%s/%dx%d-%s.%s',
            $wiki->opt('dir.cache'),
            $image->{width},
            $image->{height},
            $image->{name_ne},
            $image->{ext};
    symlink $image->{full_name}, $scale_path
        unless -e $scale_path;
}


# default image calculator for a wiki.
sub _wiki_default_calc {
    my %img  = @_;
    my $wiki = $img{wiki} || $img{page}{wiki};
    my $file = $wiki->path_for_image($img{file});

    # find the image size using GD.
    my $full_image      = GD::Image->new($file) or return (0, 0, 0, 0);
    my ($big_w, $big_h) = $full_image->getBounds();
    undef $full_image;

    # call the default handler with these full dimensions.
    # provide big_width and big_height so that Image::Size is not used.
    my ($w, $h, undef, undef, $full_size) = Wikifier::Page::_default_calculator(
        %img,
        big_width  => $big_w,
        big_height => $big_h
    );

    # pregenerate if necessary.
    # this allows the direct use of the cache directory as served from
    # the web server, reducing the wikifier server's load when requesting
    # cached pages and their images.
    if ($wiki->opt('image.enable.pregeneration') && $img{gen_override}) {
        my $res = $wiki->display_image(
            [ $img{file}, $w, $h ],
            dont_open       => 1,
            gen_override    => 1
        );
        my ($image_dir, $cache_dir) = (
            $wiki->opt('dir.image'),
            $wiki->opt('dir.cache')
        );
        unlink
            "$cache_dir/$img{file}";
        symlink
            File::Spec->abs2rel($image_dir, $cache_dir).'/'.$img{file},
            "$cache_dir/$img{file}";
    }

    return ($w, $h, $big_w, $big_h, $full_size);
}

# default image sizer for a wiki.
# this returns a URL for an image of the given dimensions.
sub _wiki_default_sizer {
    my %img = @_;
    my $wiki = $img{wiki} || $img{page}{wiki};

    # full-size image.
    if (!$img{width} || !$img{height}) {
        return $wiki->opt('root.image').'/'.$img{file};
    }

    # scaled image.
    return $wiki->opt('root.image')."/$img{width}x$img{height}-$img{file}";
}

# returns a filename-to-metadata hash for all images in the wiki
sub get_images {
    my ($wiki, %images) = shift;
    my @cat_names = map substr($_, 0, -4), $wiki->all_categories('image');
    
    # do categories first.
    # images without category files will be skipped.
    foreach my $filename (@cat_names, $wiki->all_images) {
        next if $images{$filename};
        my $image_data = $wiki->get_image($filename) or next;
        $filename = $image_data->{file};
        $images{$filename} = $image_data;
    }
    
    return \%images;
}

# returns metadata for an image
sub get_image {
    my ($wiki, $filename) = @_;
    my $path = $wiki->path_for_image($filename);
    my $cat_path = $wiki->path_for_category($filename, 'image');

    # neither the image nor a category for it exist. this is a ghost
    return if !-f $path && !-f $cat_path;

    # basic info available for all images
    my @stat = stat $path; # might be empty
    my $image_data = {
        file        => $filename,
        created     => $stat[10],   # ctime, probably overwritten
        mod_unix    => $stat[9]     # mtime, probably overwritten
    };

    # from this point on, we need the category
    return $image_data unless -f $cat_path;

    # it exists; let's see what's inside.
    my %cat = hash_maybe eval { $json->decode(file_contents($cat_path)) };
    return $image_data if !scalar keys %cat;

    # in the category, "file" is the cat filename, and the "category"
    # is the normalized image filename. remove these to avoid confusion.
    # the original image filename is image_file, so overwrite file.
    delete @cat{'category', 'file'};
    $cat{file} = delete $cat{image_file} if length $cat{image_file};
    
    # inject metadata from category
    @$image_data{ keys %cat } = values %cat;
    $image_data->{title} //= $image_data->{file};
    
    return $image_data;
}

1
