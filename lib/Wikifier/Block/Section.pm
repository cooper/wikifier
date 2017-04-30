# Copyright (c) 2017, Mitchell Cooper
#
# sections are containers for paragraphs, image boxes, etc., each with a title.
#
package Wikifier::Block::Section;

use warnings;
use strict;

use Scalar::Util qw(blessed);
use Wikifier::Utilities qw(trim page_name_link);
use HTML::Strip;

my $stripper = HTML::Strip->new(emit_spaces => 0);

our %block_types = (
    section => {
        parse => \&section_parse,
        html  => \&section_html,
        title => 1
    },
    sec => {
        alias => 'section',
    },
    clear => {
        html => \&clear_html
    }
);

sub section_parse {
    my ($block, $page) = @_;
    my $enable = $page->page_opt('page.enable.title');
    $enable = $enable ? 1 : 0;
    
    # @page.enable.title causes the first header to be larger than the
    # rest. it also uses @page.title as the first header if no other text
    # is provided.
    my $is_intro = $block->{is_intro} =
        !$page->{section_n}++ && $enable;
        
    # top-level headers start at h2 when @page.enable.title is true, since the
    # page title is the sole h1. otherwise, h1 is top-level.
    my $l = ($block->parent->{header_level} || $enable) + 1;
    
    # intro is always h1, max is h6
    $l = 1 if $is_intro;
    $l = 6 if $l > 6;
    
    $block->{header_level} = $l;
}

sub section_html {
    my ($block, $page, $el) = @_;

    # clear at end of element.
    $el->configure(clear => 1);

    # determine if this is the intro section.
    my $l = $block->{header_level};
    my $is_intro = $block->{is_intro};
    my $class = $is_intro ? 'section-page-title' : 'section-title';

    # use the page title if no other title is provided and @page.enable.title
    # is true.
    my $title = $block->name;
    $title = $page->get('page.title') if $is_intro && !length $title;

    # if we have a title and this type of title is enabled.
    if (length $title) {
        
        # parse text formatting in title
        my $title_fmt = $page->parse_formatted_text($title,
            pos => $block->create_pos
        );
        
        # meta section may be the heading ID
        my $heading_id = $block->meta('section');
        
        # otherwise textify the title, collapse whitespace, and normalize
        # in the usual wikifier way
        if (!length $heading_id) {
            $heading_id = $stripper->parse($title_fmt);
            $heading_id =~ s/\s+/ /g;
            $heading_id = page_name_link($heading_id);
        }
        
        # add -n as needed if this is already used
        my $n = $page->{heading_ids}{$heading_id}++;
        $heading_id .= "-$n" if $n;
        
        # create the heading.
        my $heading = Wikifier::Element->new(
            type       => "h$l",
            class      => $class,
            attributes => { id => $heading_id },
            content    => $title_fmt,
            container => 1
        );

        $el->add($heading);
    }
    
    my $create_paragraph = sub {
        my ($texts, $positions) = @_;
        return if !@$texts;
        
        # create the paragraph.
        my $item = $page->wikifier->create_block(
            parent      => $block,
            type        => 'paragraph',
            position    => [ @$positions ],
            content     => [ @$texts ]
        );

        # adopt it.
        $item->parse($page);
        $el->add($item->html($page));
    };

    # add the contained elements.
    my (@texts, @positions);
    foreach ($block->content_visible_pos) {
        my ($item, $pos) = @$_;

        # this is blessed, so it's a block.
        # adopt this element.
        if (blessed $item) {
            $create_paragraph->(\@texts, \@positions);
            @texts = ();
            @positions = ();
            $el->add($item->html($page));
            next;
        }

        # if this is an empty line, start a new paragraph
        if (!length trim($item)) {
            $create_paragraph->(\@texts, \@positions);
            @texts = ();
            @positions = ();
            next;
        }

        push @texts, $item;
        push @positions, $pos;
    }
    
    $create_paragraph->(\@texts, \@positions);
}

sub clear_html {
    my ($block, $page, $el) = @_;
    $el->add_class('clear');
}

__PACKAGE__
