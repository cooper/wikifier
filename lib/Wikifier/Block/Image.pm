#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# image blocks represent a single HTML image.
# this is rarely used inside of a section. most images are displayed using imageboxes
# instead. however, some hash-based blocks such as infoboxes make use of plain old images.
#
package Wikifier::Block::Image;

use warnings;
use strict;
use feature qw(switch);
use parent 'Wikifier::Block::Hash';

use Carp;

sub new {
    my ($class, %opts) = @_;
    $opts{type} = 'image';
    return $class->SUPER::new(%opts);
}

# Hash handles the actual parsing; this assigns
# properties to the image from the found values.
sub parse {
    my $block = shift;
    $block->SUPER::parse(@_) or return;
    
    $block->{$_} = $block->{hash}{$_} foreach qw(file width height);
    
    # no width or height specified; default to 100 width.
    if (!$block->{width} && !$block->{height}) {
        $block->{width} = 100;
    }
    
    # default to auto.
    $block->{width}  ||= 'auto';
    $block->{height} ||= 'auto';
    
    # no file - this is mandatory.
    if (!length $block->{file}) {
        croak "no file specified for image";
        return;
    }
    
    return 1;
}

# HTML.
sub result {
    my ($block, $page) = (shift, @_);
    
    # currently only exact pixel sizes or 'auto' are supported.
    my $px_h = $block->{height}; my $px_w = $block->{width};
    my ($w, $h) = ($px_w, $px_h);
    $px_h  =~ s/px// if defined $px_h;
    $px_w  =~ s/px// if defined $px_w;
    
    my ($link_address, $image_url) = q();
    my $image_root = $page->wiki_info('image_address');
    
    # direct link to image.
    $link_address = $image_url = "$image_root/$$block{file}";
    
    # we just won't do anything special.
    if (lc $page->wiki_info('size_images') eq 'javascript') {
        $image_url = "$image_root/$$block{file}";
    }
    
    # use server-side image sizing.
    elsif (lc $page->wiki_info('size_images') eq 'server') {
    
        # call the image_sizer.
        my $url = $page->wiki_info('image_sizer')->(
            file   => $block->{file},
            height => $px_h,
            width  => $px_w
        );
    
        $image_url = $url;
    }
    return <<END;
<div class="wiki-image">
    <a href="$link_address"><img style="height: $h; width: $w;" src="$image_url" alt="image" /></a>
</div>
END
}

1
