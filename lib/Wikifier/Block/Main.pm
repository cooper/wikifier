#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# Wikifier::Block represents a parsing block, such a section, paragraph, infobox, etc.
# With the exception of the main block, each block has a parent block. The main block is
# the implied block which surrounds all other blocks.
#
# This class is subclassed by several specific types of blocks, each which provides its
# own specific functionality.
#
package Wikifier::Block::Main;

use warnings;
use strict;
use feature qw(switch);
use parent 'Wikifier::Block';

sub new {
    my ($class, %opts) = @_;
    $opts{type} = 'main';
    return $class->SUPER::new(%opts);
}

1
