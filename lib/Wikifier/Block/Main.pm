#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# The main block is the only block which does not have a parent. There is only one
# instance of this type of block. It is an implied block containing all first-level
# blocks.
#
package Wikifier::Block::Main;

use warnings;
use strict;
use feature qw(switch);
use parent 'Wikifier::Block';

use Scalar::Util 'blessed';

sub new {
    my ($class, %opts) = @_;
    $opts{type} = 'main';
    return $class->SUPER::new(%opts);
}

# parse() just calls all of the parse()s of the children.
sub parse {
    my $block = shift;
    
    # filter out blank items.
    $block->remove_blank();
    
    # parse each item.
    foreach my $item (@{$block->{content}}) {
        next unless blessed $item;
        $item->parse(@_);
    }
    
    return 1;
}

# HTML.
sub result {
    my ($block, $page) = @_;
    my $string = q();
    foreach my $item (@{$block->{content}}) {
        $string .= $item->result($page)."\n";
    }
    return $string;
}

1
