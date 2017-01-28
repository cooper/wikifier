#
# Copyright (c) 2014, Mitchell Cooper
#
# infoboxes display a titled box with an image and table of information.
#
package Wikifier::Block::Infobox;

use warnings;
use strict;

use Scalar::Util 'blessed';
use HTML::Entities 'encode_entities';

our %block_types = (infobox => {
    base  => 'map',
    parse => \&infobox_parse,
    html  => \&infobox_html
});

sub infobox_parse {
    my ($block, $page) = (shift, @_);
    $block->parse_base(@_); # call hash parse.

    # search for image{}.
    # apply default width.
    foreach my $item ($block->content_visible) {
        next unless blessed $item && $item->{type} eq 'image';
        $item->{default_width} = '270px';
    }
}

sub infobox_html {
    my ($block, $page, $el) = (shift, @_);
    $block->html_base($page); # call hash html.

    # display the title if it exists.
    if (length $block->{name}) {
        $el->create_child(
            class   => 'infobox-title',
            content => $page->parse_formatted_text($block->{name})
        );
    }

    # start table.
    my $table = $el->create_child(
        type  => 'table',
        class => 'infobox-table'
    );

    # append each pair.
    foreach my $pair (@{ $block->{map_array} }) {
        my ($key_title, $value, $key, $is_block) = @$pair;

        # create the row.
        my $tr = $table->create_child(
            type  => 'tr',
            class => 'infobox-pair'
        );

        # append table row with key.
        if (length $key_title) {
            $key_title = $page->parse_formatted_text($key_title);
            $tr->create_child(
                type       => 'td',
                class      => 'infobox-key',
                content    => $key_title
            );
            $tr->create_child(
                type       => 'td',
                class      => 'infobox-value',
                content    => $value
            );
        }

        # append table row without key.
        else {
            my $td = $tr->create_child(
                type       => 'td',
                class      => 'infobox-anon',
                attributes => { colspan => 2 },
                content    => $value
            );
            $td->add_class('infobox-text') if !$is_block;
        }

    } # pair
}

__PACKAGE__
