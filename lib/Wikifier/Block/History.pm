# Copyright (c) 2017, Mitchell Cooper
#
# history blocks display a table of dates and important events associated with them.
#
package Wikifier::Block::History;

use warnings;
use strict;

use Scalar::Util 'blessed';

our %block_types = (
    history => {
        base   => 'map',
        html   => \&history_html
    }
);

sub history_html {
    my ($block, $page, $el) = @_;
    $block->html_base($page); # call hash html.

    my $table = $el->create_child(
        type  => 'table',
        class => 'history-table'
    );

    # append each pair.
    foreach my $pair ($block->map_array) {
        my $tr = $table->create_child(
            type  => 'tr',
            class => 'history-pair'
        );
        $tr->create_child(
            type    => 'td',
            class   => 'history-key',
            content => \$page->parse_formatted_text(
                $pair->{key_title},
                pos => $pair->{pos}
            )
        );
        $tr->create_child(
            type    => 'td',
            class   => 'history-value',
            content => $pair->{value}
        );

    }
}

__PACKAGE__
