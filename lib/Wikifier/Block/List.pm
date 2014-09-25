#
# Copyright (c) 2014, Mitchell Cooper
#
package Wikifier::Block::List;

use warnings;
use strict;

use Scalar::Util 'blessed';

our %block_types = (list => {
    base   => 'hash',
    html   => \&list_html
});

sub list_html {
    my ($block, $page, $el) = @_;
    
    # start with a ul.
    $el->{type} = 'ul';
    
    # append each item.
    foreach my $item (@{ $block->{hash_array} }) {
        my ($key_title, $key, $value) = @$item;
        $el->create_child(
            type       => 'li',
            class      => 'list-item',
            content    => $page->parse_formatted_text($value)
        );
    }
    
}

__PACKAGE__