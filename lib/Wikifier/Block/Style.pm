# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Block::Style;

use warnings;
use strict;

use Scalar::Util 'blessed';

our %block_types = (style => {
    base   => 'map',
    parse  => \&style_parse,
    html   => \&style_html,
    title  => 1,
    invis  => 1
});

sub style_parse {
    my ($block, $page) = (shift, @_);

    # parse the hash.
    $block->{no_format_values}++;
    $block->parse_base(@_);

    my %style = (
        apply_to => [],
        rules    => $block->{map_hash}
    );

    # if the block has a name, it applies to child class(es).
    if (length $block->name) {
        my @matchers = split ',', $block->name;
        foreach my $matcher (@matchers) {
            $matcher =~ s/^\s*//g;
            $matcher =~ s/\s*$//g;

            # this element.
            if ($matcher eq 'this') {
                $style{apply_to_parent}++;
                next;
            }

            # split up matchers by space.
            # replace $blah with model-blah.
            my @matchers = split /\s/, $matcher;
            @matchers = map { (my $m = $_) =~ s/^\$/model-/; $m } @matchers;

            # element type or class, etc.
            # ex: p
            # ex: p.something
            # ex: .something.somethingelse
            push @{ $style{apply_to} }, \@matchers;
        }
    }

    # the block has no name. it applies to the parent element only.
    else {
        $style{apply_to_parent}++;
    }

    $block->{style} = \%style;
}

sub style_html {
    my ($block, $page) = (shift, @_);
    my %style     = %{ $block->{style} };
    my $parent_el = $block->parent->element;
    my @apply;
    $parent_el->{need_id}++;

    # if we're applying to main, add that.
    push @apply, [ $parent_el->{id} ] if $style{apply_to_parent};

    # add other things, if any.
    foreach my $item (@{ $style{apply_to} }) {
        unshift @$item, $parent_el->{id};
        push @apply, $item;
    }

    $style{main_el}  = $parent_el->{id};
    $style{apply_to} = \@apply;

    push @{ $page->{styles} ||= [] }, \%style;
}

__PACKAGE__
