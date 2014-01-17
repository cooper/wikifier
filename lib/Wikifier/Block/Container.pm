#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
# container provides a subclass for blocks containing other blocks.
#
package Wikifier::Block::Container;

use warnings;
use strict;
use feature qw(switch);
use parent 'Wikifier::Block';

sub new {
    my ($class, %opts) = @_;
    $opts{type} = 'container';
    return $class->SUPER::new(%opts);
}

sub _parse {
    my $block = shift;
    
    # filter blank items.
    $block->remove_blank();
    
    foreach my $item (@{$block->{content}}) {
        $item->parse(@_);
    }
}

1
