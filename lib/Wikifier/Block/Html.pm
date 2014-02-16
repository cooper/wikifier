#
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
        html  => \&html_html
    }
);

sub html_html {
    my ($block, $page, $el) = @_;
    
    foreach my $item (@{$block->{content}}) {
        $el->add($el->html($page)) and next if blessed $item;
        $el->add($item);
    }
    
}

__PACKAGE__
