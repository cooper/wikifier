#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# infoboxes display a titled box with an image and table of information.
#
package Wikifier::Block::Infobox;

use warnings;
use strict;
use feature qw(switch);
use parent 'Wikifier::Block::Hash';

sub new {
    my ($class, %opts) = @_;
    $opts{type} = 'infobox';
    return $class->SUPER::new(%opts);
}

# parse(): inherited from hash.

# 

1
