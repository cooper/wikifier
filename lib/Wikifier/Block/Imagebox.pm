#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
# imageboxes display a linked image previews with a caption.
#
package Wikifier::Block::Imagebox;

use warnings;
use strict;

use Carp;
use HTML::Entities qw(encode_entities);

our %block_types = (
    imagebox => {
        base  => 'hash',
        parse => \&imagebox_parse,
        html  => \&imagebox_html
    }
);

# Hash handles the actual parsing; this assigns
# properties to the imagebox from the found values.
sub imagebox_parse {
    my ($block, $page) = (shift, @_);
    $block->parse_base(@_);
    
    $block->{$_} = $block->{hash}{$_} foreach qw(
        description file width height
        align float author license
    );
    
    # no width or height specified; default to 100 width.
    if (!$block->{width} && !$block->{height}) {
        $block->{width} = 100;
    }
    else {
        $block->{width}  =~ s/px// if defined $block->{width};
        $block->{height} =~ s/px// if defined $block->{height};
    }
    
    # default to auto.
    $block->{width}  ||= 'auto';
    $block->{height} ||= 'auto';
    
    # no float; default to right.
    $block->{float} ||= $block->{align} || 'right';
    
    # no file - this is mandatory.
    if (!length $block->{file}) {
        carp "no file specified for imagebox";
        return;
    }
    
    # TODO: what should we do if a description is omitted?
    
    # if we have an 'author' or 'license', save this reference. XXX: cite
    if (defined $block->{author} || defined $block->{license}) {
        my $ref = q();

        if (defined $block->{author} && defined $block->{license}) {
            $ref = 'By '.$block->{author}.', released under [i]'.$block->{license}.'[/i]';
        }
        
        else {
            $ref = $block->{author} ?
            'By '.$block->{author}  :
            'Released under [i]'.$block->{license}.'[/i]';
        }
        
        # store for later.
        $block->{citation} = $page->{auto_ref}++;
        push @{$page->{references}}, [$block->{citation}, $ref];
        
    }
    
    return 1;
}

# HTML.
sub imagebox_html {
    my ($block, $page, $el) = @_;
    my ($w, $h, $link_address, $image_url, $image_root, $javascript, $height, $width);
    
    ($height, $width) = ($block->{height}, $block->{width});
    $image_root       = $page->wiki_info('image_root');
    $link_address     = $image_url = "$image_root/$$block{file}";
    
    $el->add_class('imagebox-'.$block->{float});
    
    ##############
    ### SIZING ###
    ##############
    
    # decide which dimension(s) were given.
    my $given_width  = defined $width  && $width  ne 'auto' ? 1 : 0;
    my $given_height = defined $height && $height ne 'auto' ? 1 : 0;
    
    # both dimensions were given, so we need to do no sizing.
    if ($given_width && $given_height) {
        $w =  $width.q(px);
        $h = $height.q(px);
    }
    
    # use javascript image sizing
    # - uses full-size images directly and uses javascript to size imageboxes.
    # - this voids the validity as XHTML 1.0 Strict.
    # - causes slight flash on page load (when images are scaled.)
    elsif (lc $page->wiki_info('size_images') eq 'javascript') {
    
        # inject javascript resizer if no width is given.
        if (!$given_width) {
            $javascript = 1;
        }
        
        # use the image root address options to determine URL.
        
        # width and height dummies will be overriden by JavaScript.
        $w = $given_width  ? $width  : '200px';
        $h = $given_height ? $height : 'auto';
        
        $image_url = "$image_root/$$block{file}";
    }
    
    # use server-side image sizing.
    # - maintains XHTML 1.0 Strict validity.
    # - eliminates flash on page load.
    # - faster (since image files are smaller.)
    # - require read access to local image directory.
    elsif (lc $page->wiki_info('size_images') eq 'server') {
    
        # find the resized dimensions.
        ($w, $h) = $page->wiki_info('image_calc')->(
            file   => $block->{file},
            height => $height,
            width  => $width,
            page   => $page
        );
        
        # call the image_sizer.
        my $url = $page->wiki_info('image_sizer')->(
            file   => $block->{file},
            height => $h,
            width  => $w,
            page   => $page
        );
    
        $image_url = $url;
        ($w, $h)   = ($w.q(px), $h.q(px));
    }
    
    ############
    ### HTML ###
    ############
    
    # create inner box with width restriction.
    my $inner = $el->create_child(
        class  => 'imagebox-inner',
        styles => { width => $w }
    );
    
    # create the anchor.
    my $a = $inner->create_child(
        type       => 'a',
        attributes => { href => $link_address }
    );
    
    # create the image.
    my $img = $a->create_child(
        type       => 'img',
        attributes => { src => $image_url },
        alt        => 'image',
        styles     => {
            width  => $w,
            height => $h
        }
    );
    
    # insert javascript if using browser sizing. 
    $img->add_attribute(onload =>
        q{this.parentElement.parentElement.style.width = }.
        q{this.offsetWidth + 'px'; this.style.width = '100%';}
    ) if $javascript;
    
    # description.
    my $desc = $inner->create_child(class => 'imagebox-description');
    $desc->create_child(
        class   => 'imagebox-description-inner',
        content => encode_entities($page->parse_formatted_text($block->{description}))
    );

}

__PACKAGE__
