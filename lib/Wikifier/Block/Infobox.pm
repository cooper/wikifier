#
# Copyright (c) 2014, Mitchell Cooper
#
# infoboxes display a titled box with an image and table of information.
#
package Wikifier::Block::Infobox;

use warnings;
use strict;

use Scalar::Util qw(blessed);
use HTML::Entities qw(encode_entities);
use Wikifier::Utilities qw(hash_maybe);

our %block_types = (
    infobox => {
        base  => 'map',
        parse => \&infobox_parse,
        html  => \&infobox_html
    },
    infosec => {
        base  => 'map',
        parse => \&infosec_parse,
        html  => \&infosec_html,
        invis => 1
    }
);

sub infobox_parse {
    my ($infobox, $page) = (shift, @_);
    $infobox->parse_base(@_); # call hash parse.

    # search for image{}.
    # apply default width.
    foreach my $item ($infobox->content_visible) {
        next unless blessed $item && $item->{type} eq 'image';
        $item->{default_width} = '270px';
    }
}

sub infobox_html {
    my ($infobox, $page, $el) = @_;
    $infobox->html_base($page); # call hash html.

    # display the title if it exists.
    if (length $infobox->{name}) {
        $el->create_child(
            class   => 'infobox-title',
            content => $page->parse_formatted_text($infobox->{name})
        );
    }

    # start table.
    my $table = $el->create_child(
        type  => 'table',
        class => 'infobox-table'
    );

    # append each pair.
    foreach my $pair (@{ $infobox->{map_array} }) {
        my ($key_title, $value, $key, $is_block) = @$pair;

        # if the value is from infosec{}, add each row
        if (blessed $value && $value->{is_infosec}) {
            next;
        }

        # not an infosec{}; this is a top-level pair
        table_add_row($table, $page, $key_title, $value, {
            is_block => $is_block
        });
    }
}

sub table_add_row {
    my ($table, $page, $key_title, $value, $opts_) = @_;
    my %opts = hash_maybe $opts_;

    # create the row.
    my $tr = $table->create_child(
        type  => 'tr',
        class => 'infobox-pair',
        hash_maybe $opts{tr_opts}
    );

    # append table row with key.
    if (length $key_title) {
        $key_title = $page->parse_formatted_text($key_title);
        $tr->create_child(
            type       => 'td',
            class      => 'infobox-key',
            content    => $key_title,
            hash_maybe $opts{key_opts}
        );
        $tr->create_child(
            type       => 'td',
            class      => 'infobox-value',
            content    => $value,
            hash_maybe $opts{value_opts}
        );
    }

    # append table row without key.
    else {
        my $td = $tr->create_child(
            type       => 'td',
            class      => 'infobox-anon',
            attributes => { colspan => 2 },
            content    => $value,
            hash_maybe $opts{anon_opts}
        );
        $td->add_class('infobox-text') if !$opts{is_block};
    }
}

sub infosec_parse {
    my ($infosec, $page) = (shift, @_);
    $infosec->parse_base(@_); # call hash parse.
    if ($infosec->parent->type ne 'infobox') {
        $infosec->warning('infosec{} outside of infobox{} does nothing');
    }
}

sub infosec_html {

}

__PACKAGE__
