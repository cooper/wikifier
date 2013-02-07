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
    $block->SUPER::parse() or return;
    
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
    my $block  = shift;

    # parse formatting in the image description.
    my $description = $block->wikifier->parse_formatted_text($block->{description});
    
    # TODO: do not hardcode to notroll.net!
    my $height = $block->{height}; my $width = $block->{width};
    
    # image generator does not accept units.
    $height =~ s/px//; $width =~ s/px//;
    
    # if automatic scaling is desired, omit the width and height options.
    $height = '' if $height eq 'auto'; $width = '' if $width eq 'auto';
    
    my $fullurl  =
    my $shorturl = 'http://images.notroll.net/paranoia/files/'.$block->{file};
    $shorturl   .= "?height=$height&width=$width&cropratio=";
    
    return <<END;
<div class="wiki-imagebox wiki-imagebox-$$block{align}">
    <a href="$fullurl">
        <img src="$shorturl" alt="image" style="width: $$block{width}; height: $$block{height};" />
    </a>
    <div class="wiki-imagebox-description">$description</div>
</div>
END
}

1
