#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
# insert raw HTML
#
package Wikifier::Block::Html;

use warnings;
use strict;

use Scalar::Util 'blessed';

our %block_types = (
    html => {
        base  => 'container',
        html  => \&html_html
    }
);

sub html_html {
    my $block = shift;
    my $string;
    
    foreach my $item (@{$block->{content}}) {
        $string .= $item->html and next if blessed $item;
        $string .= $item;
    }
    
    return $string;
}

__PACKAGE__
