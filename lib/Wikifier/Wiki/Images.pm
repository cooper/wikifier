# Copyright (c) 2016, Mitchell Cooper
package Wikifier::Wiki;

use warnings;
use strict;
use 5.010;

use GD;                             # image generation
use HTTP::Date qw(time2str);        # HTTP date formatting
use Digest::MD5 qw(md5_hex);        # etags
use File::Spec ();                  # simplifying symlinks
use Wikifier::Utilities qw(L align hash_maybe);

##############
### IMAGES ###
##############

# Displays an image of the supplied dimensions.
sub display_image {
    my $result = _display_image(@_);
    L align('Error', "$_[1]: $$result{error}")
        if $result->{error};
    return $result;
}
sub _display_image {
    my ($wiki, $image_name, $dont_open) = @_;
    my $result = {};

    # if $image_name is an array ref, it's given in
    # [ name, width, height ]
    if (ref $image_name eq 'ARRAY') {
        my ($name, $w, $h) = @$image_name;
        $image_name = "${w}x${h}-$name";
    }

    # parse the image name.
    my %image = %{ $wiki->parse_image_name($image_name) };
    return display_error($image{error})
        if $image{error};

    $image_name = $image{name};
    my $width   = $image{width};
    my $height  = $image{height};

    # image name and full path.
    $result->{type} = 'image';
    $result->{file} = $image_name;
    $result->{path} = $result->{fullsize_path} = $image{big_path};

    # image type and mime type.
    $result->{image_type} = $image{ext} eq 'jpg' ||
                            $image{ext} eq 'jpeg' ? 'jpeg' : 'png';
    $result->{mime} = $image{ext} eq 'png' ? 'image/png' : 'image/jpeg';

    ##################################
    ### THIS IS A FULL-SIZED IMAGE ###
    ############################################################################

    # stat for full-size image.
    my @stat = stat $image{big_path};

    # if no width or height are specified,
    # display the full-sized version of the image.
    if (!$width || !$height) {

        # only include the content if $dont_open is false
        $result->{content} = file_contents($image{big_path}, 1)
            unless $dont_open;

        $result->{modified} = time2str($stat[9]);
        $result->{mod_unix} = $stat[9];
        $result->{length}   = $stat[7];
        $result->{etag}     = make_etag($image_name, $stat[9]);

        return $result;
    }

    ##############################
    ### THIS IS A SCALED IMAGE ###
    ############################################################################

    #============================#
    #=== Retina scale support ===#
    #============================#

    # HACK: this is not a retina request, but retina is enabled, and so i
    # pregeneration. therefore, we will call ->generate_image() in order to
    # pregenerate a retina version.
    if (my $retina = $wiki->opt('image.enable.retina')) {
        my @scales = split /,/, $retina;
        foreach (@scales) {

            # the image is already retina, or pregeneration is disabled
            last if $image{retina};
            last if !$wiki->opt('image.enable.pregeneration');

            # ignore scale 1 and non-integers
            s/^\s*//;
            s/\s*$//;
            next if $_ == 1;
            next if m/\D/;

            my $retina_file = "$image{f_name_ne}\@${_}x.$image{ext}";
            $wiki->display_image($retina_file, 1);
        }
    }

    # determine the full file name of the image.
    # this may have doubled sizes for retina.
    my $cache_file = $wiki->opt('dir.cache').'/'.$image{full_name};
    $result->{cache_path} = $cache_file;

    #============================#
    #=== Finding cached image ===#
    #============================#

    # if caching is enabled, check if this exists in cache.
    if ($wiki->opt('enable.cache.image') && -f $cache_file) {
        my ($image_modify, $cache_modify) = ($stat[9], (stat $cache_file)[9]);

        # if the image's file is more recent than the cache file,
        # discard the outdated cached copy.
        if ($image_modify > $cache_modify) {
            unlink $cache_file;
        }

        # the cached file is newer, so use it.
        else {

            # only include the content if $dont_open is false
            $result->{content} = file_contents($cache_file, 1)
                unless $dont_open;

            $result->{path}         = $cache_file;
            $result->{cached}       = 1;
            $result->{modified}     = time2str($cache_modify);
            $result->{mod_unix}     = $cache_modify;
            $result->{etag}         = make_etag($image_name, $cache_modify);
            $result->{length}       = -s $cache_file;

            # symlink scaled version if necessary.
            $wiki->symlink_scaled_image(\%image) if $image{retina};

            return $result;
        }
    }

    # if image generation is disabled, we must supply the full-sized image data.
    if (!$wiki->opt('enable.cache.image')) {
        return $wiki->display_image($result, $image_name, 0, 0);
    }

    #==========================#
    #=== Generate the image ===#
    #==========================#
    $wiki->generate_image(\%image, $result);

    # the generator says to use the full-sized image.
    if (delete $result->{use_fullsize}) {

        # only include the content if $dont_open is false
        $result->{content} = file_contents($image{big_path}, 1)
            unless $dont_open;

        $result->{modified}     = time2str($stat[9]);
        $result->{mod_unix}     = $stat[9];
        $result->{length}       = $stat[7];
        $result->{etag}         = make_etag($image_name, $stat[9]);
    }

    delete $result->{content} if $dont_open;
    return $result;
}

# parse an image name such as:
#
#   250x250-some_pic.png
#   250x250-some_pic\@2x.png (w/o slash)
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
        return { error => "Image '$image_name' does not exist." };
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
#
# $result is to be passed only from an existing display_image() request.
# if this is called from outside of a request, do not specify $result.
#
sub generate_image {
    my ($wiki, $_image, $result) = @_;

    # parse image name
    $_image   = $wiki->parse_image_name($_image) unless ref $_image eq 'HASH';
    my %image = %$_image;

    # an error occurred.
    return display_error($image{error})
        if $image{error};

    # no result hash reference; create one with default values.
    $result ||= do {

        # determine image short name, extension, and mime type.
        my $mime = $image{ext} eq 'png' ? 'image/png' : 'image/jpeg';
        my $type = $mime eq 'image/png' ? 'png'       : 'jpeg';

        # base $result
        {
            type          => 'image',
            file          => $image{name},
            path          => $image{path} || $image{big_path},
            fullsize_path => $image{big_path},
            cache_path    => $wiki->opt('dir.cache').'/'.$image{full_name},
            image_type    => $type,
            mime          => $mime
        }
    };


    # if we are restricting to only sizes used in the wiki, check.
    my ($width, $height) = ($image{width}, $image{height});
    if ($wiki->opt('image.enable.restriction')) {
        my $dimension_str = "${width}x${height}";
        return display_error(
            "Image '$image{name}' does not exist in those dimensions."
        ) if !$wiki->{allowed_dimensions}{ $image{name} }{$dimension_str};
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
        L(
            "Skipped '$image{name}' ${width}x${height}".
            " >= ${fi_width}x${fi_height}"
        );

        # symlink to the full-sized image.
        $image{full_name} = $image{name};
        $wiki->symlink_scaled_image(\%image) if $image{retina};

        return $result;
    }

    # create resized image.
    my $image = GD::Image->new($width, $height);
    return display_error("Couldn't create an empty image")
        if !$image;
    $image->saveAlpha(1);
    $image->alphaBlending(0);
    $image->copyResampled($full_image,
        0, 0,
        0, 0,
        $width, $height,
        ($fi_width, $fi_height)
    );

    # create JPEG
    my $use = $wiki->opt('image.type') || $result->{image_type};
    if ($use eq 'jpeg') {
        my $compression = $wiki->opt('image.quality') || 100;
        $result->{content} = $image->jpeg($compression);
    }

    # create PNG
    else {
        $image->saveAlpha(1);
        $image->alphaBlending(0);
        $result->{content} = $image->png();
    }

    $result->{generated}    = 1;
    $result->{modified}     = time2str(time);
    $result->{mod_unix}     = time;
    $result->{length}       = length $result->{content};
    $result->{etag}         = make_etag($image{name}, time);

    # caching is enabled, so let's save this for later.
    my $cache_file = $result->{cache_path};
    if ($wiki->opt('enable.cache.image')) {

        open my $fh, '>', $cache_file;
        print {$fh} $result->{content};
        close $fh;

        # overwrite modified date to actual.
        my $modified = (stat $cache_file)[9];
        $result->{path}       = $cache_file;
        $result->{modified}   = time2str($modified);
        $result->{mod_unix}   = $modified;
        $result->{cache_gen}  = 1;
        $result->{etag}       = make_etag($image{name}, $modified);

        # if this image is available in more than 1 scale, symlink.
        $wiki->symlink_scaled_image(\%image) if $image{retina};

    }

    L(
        "Generated image '$image{name}' at ${width}x${height}" .
        ($image{retina} ? " (\@$image{retina}x)" : '')
    );
    return $result;
}

# symlink an image to its scaled version
sub symlink_scaled_image {
    my ($wiki, %image) = (shift, %{ +shift });
    return unless $image{retina};
    my $scale_path = sprintf '%s/%dx%d-%s@%dx.%s',
        $wiki->opt('dir.cache'),
        $image{r_width},
        $image{r_height},
        $image{name_wo_ext},
        $image{retina},
        $image{ext};
    return 1 if -e $scale_path;
    symlink $image{full_name}, $scale_path;

    # note: using full_name rather than $cache_file
    # results in a relative rather than absolute symlink.
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
        my $res = $wiki->display_image([ $img{file}, $w, $h ], 1);
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

    # full-sized image.
    if (!$img{width} || !$img{height}) {
        return $wiki->opt('root.image').'/'.$img{file};
    }

    # scaled image.
    return $wiki->opt('root.image')."/$img{width}x$img{height}-$img{file}";
}

# returns a filename-to-metadata hash for all images in the wiki
sub get_images {
    my $wiki = shift;
    my %images;
    foreach my $filename ($wiki->all_images) {

        # basic info available for all images
        my @stat = stat $wiki->path_for_image($filename);
        my $image_data = $images{$filename} = {
            file        => $filename,
            created     => $stat[10],   # ctime
            mod_unix    => $stat[9],    # mtime
            title       => $filename    # may be overwritten by category
        };

        # this category does not exist
        my $cat_file = $wiki->path_for_category($cat_name, $cat_type);
        next unless -f $cat_file;

        # it exists; let's see what's inside.
        my %cat = hash_maybe eval { $json->decode(file_contents($cat_file)) };
        next if !scalar keys %cat;

        # in the category, "file" is the cat filename, and the "category"
        # is the image filename. remove these to avoid confusion.
        # "mod_unix" refers to the category modification time, and "created"
        # is the category creation time. remove these as well.
        delete @cat{'file', 'category', 'mod_unix', 'created'};

        # inject metadata from category
        @$image_data{ keys %cat } = values %cat;
    }
    return \%images;
}

1
