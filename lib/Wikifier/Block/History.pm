#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
# history blocks display a table of dates and important events associated with them.
#
package Wikifier::Block::History;

use warnings;
use strict;

use Scalar::Util 'blessed';

our %block_types = (
    history => {
        base   => 'hash',
        html   => \&history_html
    }
);

sub history_html {
    my ($block, $page, $el) = @_;
    my $table = $el->create_child(
        type  => 'table',
        class => 'history-table'
    );
    
    # append each pair.
    foreach my $pair (@{$block->{hash_array}}) {
        my ($key, $value) = @$pair;
        
        # value is a block. generate the HTML for it.
        if (blessed $value) {
            $value = $value->html($page);
        }
        
        # Parse formatting in the value.
        else {
            $value = $page->parse_formatted_text($value);
        }
        
        my $tr = $table->create_child(
            type  => 'tr',
            class => 'history-pair'
        );
        $tr->create_child(
            type    => 'td',
            class   => 'history-key',
            content => $page->parse_formatted_text($key)
        );
        $tr->create_child(
            type    => 'td',
            class   => 'history-value',
            content => $value
        );

    }

}

__PACKAGE__
