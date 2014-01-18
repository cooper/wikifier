#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
# The main block is the only block which does not have a parent. There is only one
# instance of this type of block. It is an implied block containing all first-level
# blocks.
#
package Wikifier::Block::Main;

use warnings;
use strict;

use Scalar::Util 'blessed';

our %block_types = (
    main => {
        parse => \&main_parse,
        html  => \&main_html
    }
);

sub main_parse {
    my $block = shift;
    
    # filter out blank items.
    $block->remove_blank();
    
    # parse each item.
    foreach my $item (@{$block->{content}}) {
        next unless blessed $item;
        print "parsing $$item{type}\n";
        $item->parse(@_);
    }
    
    return 1;
}

sub main_html {
    my ($block, $page) = @_;
    my $string = q();
    foreach my $item (@{$block->{content}}) {
        next unless blessed $item;
        $string .= $item->html($page)."\n";
    }
    return $string;
}

__PACKAGE__
