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
    my $string = '<div class="wiki-imagebox ';
    
    # class based on alignment.
    $string .= "wiki-imagebox-$$block{align}\">\n";
    
    # link and image.
    $string .= "    <a href=\"full url\">\n";
    $string .= "        <img src=\"short url\" ";
    
    # width/height.
    $string .= "style=\"width: $$block{width}; height: $$block{height};\" />\n";
    
    # end of link.
    $string .= "    </a>\n";
    
    # description.
    $string .= "    <div class=\"wiki-imagebox-description\">$$block{description}</div>\n";
    
    # end of box.
    $string .= "</div>";
    
    return $string;
}

1
