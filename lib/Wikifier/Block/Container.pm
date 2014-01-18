#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
# container provides a subclass for blocks containing other blocks.
#
package Wikifier::Block::Container;

use warnings;
use strict;
use feature qw(switch);

use Scalar::Util 'blessed';

our %block_types = (
    container => {
        parse => \&container_parse
    }
);

sub container_parse {
    my $block = shift;
    
    # filter blank items.
    $block->remove_blank();
    
    foreach my $item (@{$block->{content}}) {
        next unless blessed $item;
        $item->parse(@_);
    }
    
}

__PACKAGE__
