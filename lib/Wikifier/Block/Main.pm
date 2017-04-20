# Copyright (c) 2017, Mitchell Cooper
#
# The main block is the only block which does not have a parent. There is only one
# instance of this type of block. It is an implied block containing all first-level
# blocks.
#
package Wikifier::Block::Main;

use warnings;
use strict;

use Scalar::Util qw(blessed);
use Digest::MD5 qw(md5_hex);
use Wikifier::Utilities qw(trim_count truncate_hr);

our %block_types = (
    main => {
        parse => \&main_parse,
        html  => \&main_html
    }
);

sub main_parse {
    my ($block, $page) = @_;
    
    my $create_section = sub {
        my ($items, $positions) = @_;
        return if !@$items;
        
        # create the section.
        my $item = $page->wikifier->create_block(
            parent      => $block,
            type        => 'section',
            position    => [ @$positions ],
            content     => [ @$items ]
        );

        # adopt it.
        $el->add($item->html($page));
    };

    my (@items, @positions);
    foreach ($block->content_visible_pos) {
        my ($item, $pos) = @$_;
        
        # this is a top-level block.
        if (blessed $item) { # && $item->type eq 'Section'
            $create_section->(\@items, \@positions);
            @items = ();
            @positions = ();
            $el->add($item->html($page));
            next;
        }

        # this is text.
        # trim the text and increment the line number appropriately
        if (!blessed $item) {
            ($item, my $removed) = trim_count($item);
            $pos->{line} += $removed;
            next unless length $item;
        }
        
        # stray items will be passed to a new section{}
        push @items, $item;
        push @positions, $pos;
    }

    $create_section->(\@items, \@positions);
    return 1;
}

sub main_html {
    my ($block, $page, $el) = @_;

    # generate a better ID.
    $el->configure(
        id      => 'main-'.time.substr(md5_hex($page->path), 0, 5),
        need_id => 1
    );

    foreach my $item ($block->content_blocks) {
        $el->add($item->html($page));
    }
}

__PACKAGE__
