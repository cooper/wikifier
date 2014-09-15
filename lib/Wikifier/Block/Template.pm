#
# Copyright (c) 2014, Mitchell Cooper
#
package Wikifier::Block::Template;

use warnings;
use strict;

use Scalar::Util 'blessed';

our %block_types = (
    template => {
        base   => 'hash',
        html   => \&template_html
    }
);

sub template_html {
    my ($block, $page, $el) = @_;

    foreach my $item (@{ $block->{content} }) {
        next if blessed $item;
        # NOTE: we need to do something to get rid of the "wiki-main" from the main
        # perhaps we can replace it with template or something
        
    }

}

__PACKAGE__
