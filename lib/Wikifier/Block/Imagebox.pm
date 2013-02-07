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

sub new {
    my ($class, %opts) = @_;
    $opts{type} = 'imagebox';
    return $class->SUPER::new(%opts);
}

# parse(): inherited from hash.

# 

1
