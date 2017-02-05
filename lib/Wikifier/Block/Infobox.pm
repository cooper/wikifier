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
        html  => \&infobox_html,
        title => 1
    },
    infosec => {
        base  => 'map',
        parse => \&infosec_parse,
        html  => \&infosec_html,
        multi => 1,  # infosec{} produces more than one element
        title => 1
    }
);

sub infobox_parse {
    my ($infobox, $page) = (shift, @_);
    $infobox->parse_base(@_); # call hash parse.
}

sub infobox_html {
    my ($infobox, $page, $table) = @_;
    $infobox->html_base($page); # call hash html.
    $table->configure(type => 'table');

    # display the title if it exists.
    if (length $infobox->name) {
        $table->create_child(type => 'tr')->create_child(
            type        => 'th',
            class       => 'infobox-title',
            attributes  => { colspan => 2 },
            content     => $page->parse_formatted_text(
                $infobox->name,
                pos => $infobox->pos
            )
        );
    }

    table_add_rows($table, $page, $infobox);
}

# append each pair.
# note that $table might actually be a Wikifier::Elements container
sub table_add_rows {
    my ($table, $page, $block) = @_;
    my @pairs = @{ $block->{map_array} };
    my $has_title = 0;
    for (0..$#pairs) {
        my ($key_title, $value, $key, $is_block, $pos, $is_title) =
            @{ $pairs[$_] };
        my $next = $pairs[$_ + 1];

        # if the value is from infosec{}, add each row
        if (blessed $value && $value->{is_infosec}) {
            #warning("Key associated with infosec{} ignored")
            #    if length $key_title;
            $table->add($value);
            next;
        }

        # options based on position in the infosec
        my @classes;
        push @classes, 'infosec-title' and $has_title++ if $is_title;
        push @classes, 'infosec-first' if $_ == $has_title;
        my $b4_infosec = $next && blessed $next->[1] && $next->[1]{is_infosec};
        push @classes, 'infosec-last'
            if !$is_title && ($b4_infosec || $_ == $#pairs);

        my %row_opts = (
            is_block => $is_block,
            is_title => $is_title,
            td_opts  => { classes => \@classes }
        );

        # not an infosec{}; this is a top-level pair
        table_add_row($table, $page, $key_title, $value, $pos, \%row_opts);
    }
}

# add a row.
# note that $table might actually be a Wikifier::Elements container
sub table_add_row {
    my ($table, $page, $key_title, $value, $pos, $opts_) = @_;
    my %opts    = hash_maybe $opts_;
    my %td_opts = hash_maybe $opts{td_opts};

    # create the row.
    my $tr = $table->create_child(
        type  => 'tr',
        class => 'infobox-pair'
    );

    # append table row with key.
    if (length $key_title) {
        $key_title = $page->parse_formatted_text($key_title, pos => $pos);
        $tr->create_child(
            type       => 'th',
            class      => 'infobox-key',
            content    => $key_title,
            %td_opts
        );
        $tr->create_child(
            type       => 'td',
            class      => 'infobox-value',
            content    => $value,
            %td_opts
        );
    }

    # append table row without key.
    else {
        my $td = $tr->create_child(
            type       => 'td',
            class      => 'infobox-anon',
            attributes => { colspan => 2 },
            content    => $value,
            %td_opts
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
    if ($infosec->parent->type ne 'infobox' && !$infosec->{is_variable}) {
        $infosec->warning('infosec{} outside of infobox{} does nothing');
        return;
    }

    # inject the title
    if (length(my $title = $infosec->name)) {
        unshift @{ $infosec->{map_array} }, [
            undef,              # no key title
            $page->parse_formatted_text($title, pos => $infosec->pos),
            '_infosec_title_',  # the real key
            undef,              # block?
            undef,              # position
            1                   # title?
        ];
    }

    table_add_rows($els, $page, $infosec);
}

__PACKAGE__
