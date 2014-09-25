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
    base  => 'hash',
    parse => \&infobox_parse,
    html  => \&infobox_html
});

sub infobox_parse {
    my ($block, $page) = (shift, @_);
    $block->parse_base(@_); # call hash parse.
    
    # search for image{}.
    foreach my $item (@{ $block->{content} }) {
        next unless blessed $item;
        next unless $item->isa('Wikifier::Block');
        next unless $item->{type} eq 'image';
        
        # parse the image ahead of time.
        $item->parse(@_);
        
        # found one. does it have a width?
        # if not, fall back to 270px.
        $item->{width} = '270px' if $item->{width} eq 'auto';
        
    }
    
}

sub infobox_html {
    my ($block, $page, $el) = @_;
    
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
    foreach my $pair (@{ $block->{hash_array} }) {
        my ($key_title, $value, $key) = @$pair;

        # value is a block. generate the HTML for it.
        if (blessed $value) {
            $value = $value->html($page);
        }
        
        # Parse formatting in the value.
        else {
            $value = $page->parse_formatted_text($value);
        }
        
        # Parse formatting in the key.
        if (length $key_title) {
            $key_title = $page->parse_formatted_text($key_title);
        }
        
        # create the row.
        my $tr = $table->create_child(
            type  => 'tr',
            class => 'infobox-pair'
        );
        
        # append table row with key.
        if (length $key_title) {
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
            $tr->create_child(
                type       => 'td',
                class      => 'infobox-anon',
                attributes => { colspan => 2 },
                content    => $value
            );
        }

    } # pair
}

__PACKAGE__
