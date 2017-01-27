#
# Copyright (c) 2014, Mitchell Cooper
#
# anything inside this block will not be displayed
#
package Wikifier::Block::Invisible;

use warnings;
use strict;

use Scalar::Util 'blessed';

our %block_types = (
    invisible => {
        parse => \&parse_invisible,
        html  => \&html_invisible
    }
);

sub parse_invisible {
    my ($block, $page) = @_;
    # foreach my $item (@{ $block->{content} }) {
    #     next unless blessed $item;
    #     $item->parse($page);
    # }
}

sub html_invisible {
    my ($block, $page) = @_;
    # foreach my $item (@{ $block->{content} }) {
    #     next unless blessed $item;
    #     $item->html($page);
    # }
}

__PACKAGE__
