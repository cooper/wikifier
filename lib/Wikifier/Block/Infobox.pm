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
        #invis => 1, # the html is added manually in infobox_html
        multi => 1  # infosec{} produces more than one element
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

    table_add_rows($table, $page, $infobox);
}

# append each pair.
# note that $table might actually be a Wikifier::Elements container
sub table_add_rows {
    my ($table, $page, $block, $opts_) = @_;
    my %opts  = hash_maybe $opts_;
    my @pairs = @{ $block->{map_array} };
    for (0..$#pairs) {
        my ($key_title, $value, $key, $is_block) = @{ $pairs[$_] };

        # if the value is from infosec{}, add each row
        if (blessed $value && $value->{is_infosec}) {
            #warning("Key associated with infosec{} ignored")
            #    if length $key_title;
            $table->add($value);
            next;
        }

        # options based on position in the infosec
        my %row_opts = (is_block => $is_block);
        if ($#pairs == 0) {
            my %only_opts = hash_maybe $opts{only_row_opts};
            @row_opts{ keys %only_opts } = values %only_opts;
        }
        elsif ($_ == 0) {
            my %first_opts = hash_maybe $opts{first_row_opts};
            @row_opts{ keys %first_opts } = values %first_opts;
        }
        elsif ($_ == $#pairs) {
            my %last_opts = hash_maybe $opts{last_row_opts};
            @row_opts{ keys %last_opts } = values %last_opts;
        }
        else {
            my %middle_opts = hash_maybe $opts{middle_row_opts};
            @row_opts{ keys %middle_opts } = values %middle_opts;
        }

        # not an infosec{}; this is a top-level pair
        table_add_row($table, $page, $key_title, $value, \%row_opts);
    }
}

# add a row.
# note that $table might actually be a Wikifier::Elements container
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
}

sub infosec_html {
    my ($infosec, $page, $els) = @_;
    $infosec->html_base($page); # call hash html.
    $els->{is_infosec}++;

    # not in an infobox{}
    if ($infosec->parent->type ne 'infobox') {
        $infosec->warning('infosec{} outside of infobox{} does nothing');
        return;
    }

    # inject the title
    my @first_classes = 'infosec-first';
    if (length(my $title = $infosec->{name})) {
        unshift @{ $infosec->{map_array} }, [
            undef,              # no key title
            $page->parse_formatted_text($title),
            '_infosec_title_'   # the real key
        ];
        push @first_classes, 'infosec-title';
    }

    table_add_rows($els, $page, $infosec, {
        only_row_opts => {
            tr_opts => { classes => [ @first_classes, 'infosec-last' ] }
        },
        first_row_opts => {
            tr_opts => { classes => \@first_classes }
        },
        last_row_opts => {
            tr_opts => { classes => [ 'infosec-last' ] }
        }
    });
}

__PACKAGE__
