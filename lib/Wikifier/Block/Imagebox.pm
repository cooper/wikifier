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
    my ($block, $page) = (shift, @_);
    $block->SUPER::parse(@_) or return;
    
    $block->{$_} = $block->{hash}{$_} foreach qw(
        description file width height
        align author license
    );
    
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
    
    # if we have an 'author' or 'license', save this reference.
    if (defined $block->{author} || defined $block->{license}) {
        my $ref = q();

        if (defined $block->{author} && defined $block->{license}) {
            $ref = 'By [b]'.$block->{author}.'[/b], released under [i]'.$block->{license}.'[/i]';
        }
        
        else {
            $ref = $block->{author}          ?
            'By [b]'.$block->{author}.'[/b]' :
            'Released under [i]'.$block->{license}.'[/i]';
        }
        
        # store for later.
        $block->{citation} = $page->{auto_ref}++;
        push @{$page->{references}}, [$block->{citation}, $ref];
        
    }
    
    return 1;
}

# HTML.
sub result {
    my ($block, $page) = @_;
    
    # parse formatting in the image description.
    my $description = $page->parse_formatted_text($block->{description});
    
    # append citation if one exists.
    if (defined(my $ref = $block->{citation})) {
        $description .= qq{ <sup style="font-size: 75%"><a href="#wiki-ref-$ref">[$ref]</a></sup>};
    }
    
    # currently only exact pixel sizes or 'auto' are supported.
    my $height = $block->{height}; my $width = $block->{width};
    $height =~ s/px// if defined $height;
    $width  =~ s/px// if defined $width;
    
    my ($js, $h, $w, $link_address, $image_url) = q();
    my $image_root = $page->wiki_info('image_root');
    
    # direct link to image.
    $link_address = $image_url = "$image_root/$$block{file}";
    
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
            $js = q{ onload="this.parentElement.parentElement.style.width = this.offsetWidth + 'px'; this.style.width = '100%';"};
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
        ($w, $h) = $page->wiki_info('image_dimension_calculator')->(
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
    }
    
    return <<END;
<div class="wiki-imagebox wiki-imagebox-$$block{align}">
    <div class="wiki-imagebox-inner" style="width: ${w}px;">
    <a href="$link_address">
        <img src="$image_url" alt="image" style="width: ${w}px; height: ${h}px;"$js />
    </a>
    <div class="wiki-imagebox-description">
        <div class="wiki-imagebox-description-inner">$description</div>
    </div>
    </div>
</div>
END
}
1
