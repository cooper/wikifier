# Copyright (c) 2017, Mitchell Cooper
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
        html  => \&html_invisible,
        invis => 1
    }
);

sub parse_invisible {
    my ($block, $page) = @_;
}

sub html_invisible {
    my ($block, $page) = @_;
}

__PACKAGE__
