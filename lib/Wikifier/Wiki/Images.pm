# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Wiki;

use warnings;
use strict;
use 5.010;

use GD;                             # image generation
use HTTP::Date qw(time2str);        # HTTP date formatting
use Digest::MD5 qw(md5_hex);        # etags
use File::Spec ();                  # simplifying symlinks
use Wikifier::Utilities qw(L align hash_maybe);
use JSON::XS ();

my $json = JSON::XS->new->pretty(1);

##############
### IMAGES ###
##############

# Displays an image of the supplied dimensions.
#
# %opts = (
#   dont_open       don't actually read the image; {content} will be omitted
# )
sub display_image {
    my $result = _display_image(@_);
    L align('Error', "'$_[1]': $$result{error}")
        if $result->{error};
    return $result;
}
sub _display_image {
    my ($wiki, $image_name, %opts) = @_;
    my $result = {};

    # if $image_name is an array ref, it's given in
    # [ name, width, height ]
    if (ref $image_name eq 'ARRAY') {
        my ($name, $w, $h) = @$image_name;
        $image_name = "${w}x${h}-$name" if $w && $h;
    }

    # parse the image name.
    my $image = $wiki->parse_image_name($image_name);
    return display_error($image->{error})
        if $image->{error};

    $image_name = $image->{name};
    my $width   = $image->{width};
    my $height  = $image->{height};
    my @stat    = stat $image->{big_path};

    # image name and full path.
    $result->{type} = 'image';
    $result->{file} = $image_name;
    $result->{path} = $result->{fullsize_path} = $image->{big_path};

    # image type and mime type.
    $result->{image_type} = $image->{ext} eq 'jpg' ||
                            $image->{ext} eq 'jpeg' ? 'jpeg' : 'png';
    $result->{mime} = $image->{ext} eq 'png' ? 'image/png' : 'image/jpeg';

    # if a dimension is missing or image caching is disabled, display the
    # full-size version of the image.
    return $wiki->get_image_full_size($image, $result, \@stat, \%opts)
        if !$width || !$height || !$wiki->opt('image.enable.cache');

    #============================#
    #=== Retina scale support ===#
    #============================#

    # HACK: this is not a retina request, but retina is enabled, and so is
    # pregeneration. therefore, we will call ->generate_image() in order to
    # pregenerate a retina version.
    if (my $retina = $wiki->opt('image.enable.retina')) {
        my @scales = split /,/, $retina;
        foreach (@scales) {

            # the image is already retina, or pregeneration is disabled
            last if $image->{retina};
            last if !$wiki->opt('image.enable.pregeneration');

            # ignore scale 1 and non-integers
            s/^\s*//;
            s/\s*$//;
            next if m/\D/;
            next if $_ == 1;

            my $retina_file = "$$image{f_name_ne}\@${_}x.$$image{ext}";
            $wiki->display_image($retina_file, dont_open => 1);
        }
    }

    # determine the full file name of the image.
    # this may have doubled sizes for retina.
    my $cache_file = $wiki->opt('dir.cache').'/'.$image->{full_name};
    $result->{cache_path} = $cache_file;

    #=========================#
    #=== Find cached image ===#
    #=========================#

    # if caching is enabled, check if this exists in cache.
    if ($wiki->opt('image.enable.cache') && -f $cache_file) {
        $result = $wiki->get_image_cache($image, $result, $stat[9], \%opts);
        return $result if $result->{cached};
    }

    #======================#
    #=== Generate image ===#
    #======================#

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
    $result->{content} = file_contents($image->{big_path}, 1)
        unless $opts->{dont_open};

    $result->{modified}     = time2str($stat->[9]);
    $result->{mod_unix}     = $stat->[9];
    $result->{length}       = $stat->[7];
    $result->{etag}         = make_etag($image->{name}, $stat->[9]);

    return $result;
}

# get image from cache
sub get_image_cache {
    my ($wiki, $image, $result, $image_modify, $opts) = @_;
    my $cache_file   = $result->{cache_path};
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
    $result->{cached}       = 1;
    $result->{modified}     = time2str($cache_modify);
    $result->{mod_unix}     = $cache_modify;
    $result->{etag}         = make_etag($image->{name}, $cache_modify);
    $result->{length}       = -s $cache_file;

    # symlink scaled version if necessary.
    $wiki->symlink_scaled_image($image) if $image->{retina};
}

# parse an image name such as:
#
#   250x250-some_pic.png
#   250x250-some_pic@2x.png (w/o slash)
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
    my $image_name_s = $image_name;

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

    # check if the file exists.
    my $image_path = $wiki->path_for_image($image_name);
    if (!-f $image_path) {
        return { error => "Image does not exist." };
    }

    return {
        name        => $image_name,     # image name with extension,      no dimensions
        name_wo_ext => $image_wo_ext,   # image name without extension,   no dimensions
        name_scale  => $image_name_s,   # image name possibly with scale, no dimensions
        ext         => $image_ext,      # image extension
        full_name   => $full_name,      # image name with extension & dimensions
        f_name_ne   => $full_name_ne,   # image name with dimensions, no extension
        big_path    => $image_path,     # path to the full size image
        width       => $width,          # possibly scaled width
        height      => $height,         # possibly scaled height
        r_width     => $real_width,     # width without retina scaling
        r_height    => $real_height,    # height without retina scaling
        retina      => $retina_request  # if scaled for retina, the scale (e.g. 2, 3)
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
    if ($wiki->opt('image.enable.restriction')) {
        my $dimension_str = "${r_width}x${r_height}";
        return display_error(
            "Image does not exist at $dimension_str."
        ) if !$wiki->{allowed_dimensions}{ $image->{name} }{$dimension_str};
    }

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
            "'$$image{name}' at ${width}x${height}" .
            " >= original ${fi_width}x${fi_height}"
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
    $result->{etag}         = make_etag($image->{name}, time);

    # caching is enabled, so let's save this for later.
    my $cache_file = $result->{cache_path};
    if ($wiki->opt('image.enable.cache')) {

        open my $fh, '>', $cache_file;
        print {$fh} $result->{content};
        close $fh;

        # overwrite modified date to actual.
        my $modified = (stat $cache_file)[9];
        $result->{path}       = $cache_file;
        $result->{modified}   = time2str($modified);
        $result->{mod_unix}   = $modified;
        $result->{cache_gen}  = 1;
        $result->{etag}       = make_etag($image->{name}, $modified);

        # if this image is available in more than 1 scale, symlink.
        $wiki->symlink_scaled_image($image) if $image->{retina};
    }

    L align(
        'Generate',
        "'$$image{name}' at ${width}x${height}" .
        ($image->{retina} ? " (\@$$image{retina}x)" : '')
    );
    return; # success
}

# symlink an image to its scaled version
sub symlink_scaled_image {
    my ($wiki, $image) = @_;
    return unless $image->{retina};
    my $scale_path = sprintf '%s/%dx%d-%s@%dx.%s',
        $wiki->opt('dir.cache'),
        $image->{r_width},
        $image->{r_height},
        $image->{name_wo_ext},
        $image->{retina},
        $image->{ext};
    return 1 if -e $scale_path;

    # note: using full_name rather than $cache_file
    # results in a relative rather than absolute symlink.
    symlink $image->{full_name}, $scale_path;
}

# generate an etag
sub make_etag {
    my $md5 = md5_hex(join '', @_);
    return "\"$md5\"";
}

# default image calculator for a wiki.
sub _wiki_default_calc {
    my %img  = @_;
    my $page = $img{page};
    my $wiki = $page->{wiki};
    my $file = $wiki->path_for_image($img{file});

    # find the image size using GD.
    my $full_image      = GD::Image->new($file) or return (0, 0);
    my ($big_w, $big_h) = $full_image->getBounds();
    undef $full_image;

    # call the default handler with these full dimensions.
    my ($w, $h, $full_size) = Wikifier::Page::_default_calculator(
        %img,
        big_width  => $big_w,
        big_height => $big_h
    );

    # store these as accepted dimensions.
    $wiki->{allowed_dimensions}{ $img{file} }{ "${w}x${h}" } = 1;

    # pregenerate if necessary.
    # this allows the direct use of the cache directory as served from
    # the web server, reducing the wikifier server's load when requesting
    # cached pages and their images.
    if ($page->wiki_opt('image.enable.pregeneration')) {
        my $res = $wiki->display_image([ $img{file}, $w, $h ], dont_open => 1);
        my ($image_dir, $cache_dir) = (
            $page->wiki_opt('dir.image'),
            $page->wiki_opt('dir.cache')
        );
        unlink
            "$cache_dir/$img{file}";
        symlink
            File::Spec->abs2rel($image_dir, $cache_dir).'/'.$img{file},
            "$cache_dir/$img{file}";
    }

    return ($w, $h, $full_size);
}

# default image sizer for a wiki.
# this returns a URL for an image of the given dimensions.
sub _wiki_default_sizer {
    my %img = @_;
    my $page = $img{page};
    my $wiki = $page->{wiki};

    # full-size image.
    if (!$img{width} || !$img{height}) {
        return $wiki->opt('root.image').'/'.$img{file};
    }

    # scaled image.
    return $wiki->opt('root.image')."/$img{width}x$img{height}-$img{file}";
}

# returns a filename-to-metadata hash for all images in the wiki
sub get_images {
    my ($wiki, %images, %done) = shift;
    my @cat_names = map substr($_, 0, -4), $wiki->all_categories('image');
    foreach my $filename ($wiki->all_images, @cat_names) {
        next if $done{$filename}++;
        my $image_data = $wiki->get_image($filename) or next;
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
    next if !-f $path && !-f $cat_path;

    # basic info available for all images
    my @stat = stat $path; # might be empty
    my $image_data = {
        file        => $filename,
        title       => $filename,   # may be overwritten by category
        created     => $stat[10],   # ctime, probably overwritten
        mod_unix    => $stat[9]     # mtime, probably overwritten
    };

    # from this point on, we need the category
    next unless -f $cat_path;

    # it exists; let's see what's inside.
    my %cat = hash_maybe eval { $json->decode(file_contents($cat_path)) };
    next if !scalar keys %cat;

    # in the category, "file" is the cat filename, and the "category"
    # is the image filename. remove these to avoid confusion.
    delete @cat{'file', 'category'};

    # inject metadata from category
    @$image_data{ keys %cat } = values %cat;

    return $image_data;
}

1
