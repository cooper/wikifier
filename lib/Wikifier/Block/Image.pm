# Copyright (c) 2017, Mitchell Cooper
#
# image blocks represent a single HTML image.
# this is rarely used inside of a section. most images are displayed using imageboxes
# instead. however, some hash-based blocks such as infoboxes make use of plain old images.
#
# imageboxes display a linked image previews with a caption.
#
package Wikifier::Block::Image;

use warnings;
use strict;

use Wikifier::Utilities qw(L trim);
use List::Util qw(max);

our %block_types = (
    image => {
        base  => 'map',
        parse => \&image_parse,
        html  => sub { image_html(0, @_) }
    },
    imagebox => {
        base  => 'map',
        parse => \&image_parse,
        html  => sub { image_html(1, @_) }
    }
);

# Map handles the actual parsing; this assigns
# properties to the imagebox from the found values.
sub image_parse {
    my ($image, $page) = (shift, @_);
    $image->parse_base(@_); # call hash parse.

    my ($w, $h);

    # get values from hash.
    $image->{$_} = $image->{map_hash}{$_} foreach qw(
        file width height alt link
        align float author license
    );

    # no dimensions; might be able to get them from a container
    if (!$image->{width} && !$image->{height}) {
        $image->{width} = 270 if $image->first_parent('infobox');
    }

    # force numeric value.
    $image->{width}  =~ s/px// if length $image->{width};
    $image->{height} =~ s/px// if length $image->{height};
    $image->{width}  += 0;
    $image->{height} += 0;

    # no width or height specified; fall back to full dimensions.
    if (!$image->{width} && !$image->{height}) {
        $image->{width}  =
        $image->{height} = 0;
    }

    $image->{float} ||= $image->{align};
    $image->{image_root} = $page->opt('root.image');

    # no file - this is mandatory.
    if (!length $image->{file}) {
        $image->warning("No file specified for image\{}");
        $image->{parse_failed}++;
        return;
    }


    $image->{image_url}  = $image->{file};
    $image->{last_name}  = (split m{/}, $image->{file})[-1];

    ##############
    ### SIZING ###
    ##############

    # if the file is an absolute URL, we cannot size the image
    if ($image->{file} =~ m{^(.+)://}) {
        # do nothing
    }

    # both dimensions were given, so we need to do no sizing.
    # FIXME: this forces the full size image instead of generating in the
    # given dimensions
    elsif ($image->{width} && $image->{height}) {
        $w = $image->{width};
        $h = $image->{height};
    }

    # use javascript image sizing
    # - uses full-size images directly and uses javascript to size imageboxes.
    # - this voids the validity as XHTML 1.0 Strict.
    # - causes slight flash on page load (when images are scaled.)
    elsif (lc $page->opt('image.size_method') eq 'javascript') {

        # inject javascript resizer if no width is given.
        $image->{javascript}++ if !$image->{width};

        # use the image root address options to determine URL.

        # width and height dummies will be overriden by JavaScript.
        $w = $image->{width} || 200;    # width default 200
        $h = $image->{height};          # zero means auto

        $image->{image_url} = "$$image{image_root}/$$image{file}";
    }

    # use server-side image sizing.
    # - maintains XHTML 1.0 Strict validity.
    # - eliminates flash on page load.
    # - faster (since image files are smaller.)
    # - require read access to local image directory.
    elsif (lc $page->opt('image.size_method') eq 'server') {

        # find the resized dimensions.
        ($w, $h, my $big_w, my $big_h, my $full_size) = $page->opt('image.calc',
            file   => $image->{file},
            height => $image->{height},
            width  => $image->{width},
            page   => $page,
            gen_override => 1
        );

        # call the image_sizer.
        $image->{image_url} = $page->opt('image.sizer',
            file   => $image->{file},
            height => $full_size ? 0 : $h,
            width  => $full_size ? 0 : $w,
            page   => $page
        );
        
        # normalize dimensions
        $w += 0;
        $h += 0;

        # remember if we're using the fullsize version
        # so that we don't attempt to retina-scale it
        $image->{full_size} = $full_size;

        # remember that we use this image.
        push @{ $page->{images} { $image->{file} } ||= [] }, $w, $h;
        $page->{images_fullsize}{ $image->{file} } = [ $big_w, $big_h ];
    }

    # any dimensions still not set = auto.
    $image->{width}  = $w ? "${w}px" : 'auto';
    $image->{height} = $h ? "${h}px" : 'auto';

    return 1;
}

# HTML.
sub image_html {
    my ($box, $image, $page, $el) = (shift, shift, @_);
    $image->html_base($page); # call hash html.
    return if $image->{parse_failed};

    # add the appropriate float class.
    my $float = $image->{float};
    if ($box) {
        $float ||= 'right';
        $el->add_class('imagebox-'.$float);
    }
    elsif ($float) {
        $el->add_class('image-'.$float);
    }

    # fetch things we determined in image_parse().
    my ($height,          $width,          $image_url         ) =
    ($image->{height}, $image->{width}, $image->{image_url});
    
    # retina
    my $retina;
    if (!$image->{full_size} and $retina = $page->opt('image.enable.retina')) {
        my ($first, $ext) = $image_url =~ /(.*)\.(.+)/;
        my @retina = grep !m/\D/, map trim($_), split /,/, $retina;
        $retina = join ', ', map { "$first\@${_}x.$ext ${_}x" } @retina if @retina;
    }
    
    # link can be overridden
    my $link_target;
    my $link = $image->{map_hash}{link};
    if ($link && $link eq 'none') {
        undef $link;
    }
    elsif ($link) {
        $link_target = '_blank';
        my ($ok, $target) = $page->wikifier->parse_link($page, $link);
        $link = $target;
        undef $link if !$ok;
    }
    else {
        $link = $image->{image_url};
    }

    # add href and link target if there's a link
    my $img_a_attributes = { href => $link, target => $link_target };
    undef $img_a_attributes if !defined $link;

    ############
    ### HTML ###
    ############

    # this is not an image box; it's just an image.
    if (!$box) {
        my $an;
        $an = $el->create_child(
            class      => 'image-a',
            type       => 'a',
            attributes => $img_a_attributes
        ) if $link;
        my $img = ($an || $el)->create_child(
            class      => 'image-img',
            type       => 'img',
            attributes => {
                src => $image_url,
                alt => $image->{alt} // $image->{last_name}
            },
            styles => { width => $width }
        );
        $img->add_attribute(srcset => $retina) if $retina;
        return;
    }

    # create inner box with width restriction.
    my $inner = $el->create_child(
        class  => 'imagebox-inner',
        styles => { width => $width }
    );

    # create the anchor.
    my $an;
    $an = $inner->create_child(
        class      => 'imagebox-a',
        type       => 'a',
        attributes => $img_a_attributes
    ) if $link;

    # create the image.
    my $img = ($an || $inner)->create_child(
        class      => 'imagebox-img',
        type       => 'img',
        attributes => {
            src => $image_url,
            alt => $image->{alt} // $image->{last_name}
        },
        styles => { width  => $width }
    );

    # insert javascript if using browser sizing.
    $img->add_attribute(onload => 'wikifier.imageResize(this);')
        if $image->{javascript};

    # insert srcset for retina
    $img->add_attribute(srcset => $retina) if $retina;

    # description. we have to extract this here instead of in ->parse()
    # because at the time of ->parse() its text is not yet formatted.
    my $desc = $image->{map_hash}{description} // $image->{map_hash}{desc};
    if (length $desc) {
        $inner->create_child(
            class => 'imagebox-description'
        )->create_child(
            class   => 'imagebox-description-inner',
            content => $desc
        );
    }
}

__PACKAGE__
