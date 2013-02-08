#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# imageboxes display a linked image previews with a caption.
#
package Wikifier::Block::Imagebox;

use warnings;
use strict;
use feature qw(switch);
use parent 'Wikifier::Block::Hash';

use Carp;

# create a new imagebox.
sub new {
    my ($class, %opts) = @_;
    $opts{type} = 'imagebox';
    return $class->SUPER::new(%opts);
}

# Hash handles the actual parsing; this assigns
# properties to the imagebox from the found values.
sub parse {
    my $block = shift;
    $block->SUPER::parse(@_) or return;
    
    $block->{$_} = $block->{hash}{$_} foreach qw(description file width height align);
    
    # no width or height specified; default to 100 width.
    if (!$block->{width} && !$block->{height}) {
        $block->{width} = 100;
    }
    
    # default to auto.
    $block->{width}  ||= 'auto';
    $block->{height} ||= 'auto';
    
    # no alignment; default to right.
    $block->{align} ||= 'right';
    
    # no file - this is mandatory.
    if (!length $block->{file}) {
        croak "no file specified for imagebox";
        return;
    }
    
    # what should we do if a description is omitted?
    
    return 1;
}

# HTML.
sub result {
    my ($block, $page) = @_;
    
    # parse formatting in the image description.
    my $description = $page->parse_formatted_text($block->{description});
    
    # currently only exact pixel sizes or 'auto' are supported.
    my $height = $block->{height}; my $width = $block->{width};
    $height =~ s/px// if defined $height;
    $width  =~ s/px// if defined $width;
    
    my ($h, $w, $link_address, $image_url);
    my $image_root   = $page->wiki_info('image_address');
    
    # direct link to image.
    $link_address = $image_url = "$image_root/$$block{file}";
    
    # use javascript image sizing
    # - uses full-size images directly and uses javascript to size imageboxes.
    # - this voids the validity as XHTML 1.0 Strict.
    # - causes slight flash on page load (when images are scaled.)
    my $js = q();
    if (lc $page->wiki_info('size_images') eq 'javascript') {
    
        # inject javascript resizer if no width is given.
        if (!defined $width || $width eq 'auto') {
            $js = q{ onload="this.parentElement.parentElement.style.width = this.offsetWidth + 'px'; this.style.width = '100%';"};
        }
        
        # use the image root address options to determine URL.
        
        # width and height dummies will be overriden by JavaScript.
        $w = defined $width  ? $width  : '200px';
        $h = defined $height ? $height : 'auto';
        
        $image_url = "$image_root/$$block{file}";
    }
    
    # use server-side image sizing.
    # - uses Image::Size to determine dimensions.
    # - maintains XHTML 1.0 Strict validity.
    # - eliminates flash on page load.
    # - faster (since image files are smaller.)
    # - require read access to local image directory.
    elsif (lc $page->wiki_info('size_images') eq 'server') {
    
        # use Image::Size to determine the dimensions.
        require Image::Size;
        my $dir  = $page->wiki_info('image_directory');
        ($w, $h) = Image::Size::imgsize("$dir/$$block{file}");
    
        # call the image_sizer.
        my $url = $page->wiki_info('image_sizer')->(
            file   => $block->{file},
            height => $height,
            width  => $width
        );
    
        $image_url = $url;
    }
    
    return <<END;
<div class="wiki-imagebox wiki-imagebox-$$block{align}">
    <a href="$link_address">
        <img src="$image_url" alt="image" style="width: $w; height: $h;"$js />
    </a>
    <div class="wiki-imagebox-description">
        <div class="wiki-imagebox-description-inner">$description</div>
    </div>
</div>
END
}
1
