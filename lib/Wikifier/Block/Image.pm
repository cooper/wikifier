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

sub result {
    my ($block, $page) = @_;
    
    # calculate height and width.
    my $height = $block->{height}; my $width = $block->{width};
    my ($realheight, $realwidth) = ($height, $width);
    
    # image generator does not accept units.
    $height =~ s/px//; $width =~ s/px//;
    
    # if automatic scaling is desired, omit the width and height options.
    $height = '' if $height eq 'auto'; $width = '' if $width eq 'auto';
    
    # TODO: don't hardcode to notroll.net.
    my $fullurl  =
    my $shorturl = 'http://images.notroll.net/paranoia/files/'.$block->{file};
    $shorturl   .= "?height=$height&amp;width=$width&amp;cropratio=";
    
    return <<END;
<div class="wiki-image">
    <a href="$fullurl"><img style="height: $realheight; width: $realwidth;" src="$shorturl" alt="image" /></a>
</div>
END
}

1
