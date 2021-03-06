# Copyright (c) 2017, Mitchell Cooper
#
# section{} or sec{} is a container block which can contain other blocks and/or
# formatted stray text. text is automatically split into paragraphs by blank
# lines. the optional title will be displayed in the proper size in accordance
# with the section hierarchy.
#
# if the first section on a page has no title, it is assumed to be an
# introductory section and adopts the page title as its heading. this behavior
# can be disabled with -@page.enable.title;
#
# quote{} is like section{} except used for blockquotes; it may NOT have a title
# but follows the same rules for stray text.
#
# clear{} is a simple clear element which may be thought of as the HTML/CSS
# equivalent <div style="clear: both;"></div>
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
        init  => \&section_init,
        parse => \&section_parse,
        html  => \&section_html,
        title => 1
    },
    sec => {
        alias => 'section',
    },
    quote => {
        init  => \&section_init,
        html  => \&quote_html,
        title => 1
    },
    clear => {
        html => \&clear_html
    }
);

# blank lines are needed for paragraph separation
sub section_init {
    my $sec = shift;
    $sec->{dont_remove_blank}++;
}

sub section_parse {
    my ($sec, $page) = @_;
    my $enable = $page->page_opt('page.enable.title');
    $enable = $enable ? 1 : 0;
    
    # @page.enable.title causes the first header to be larger than the
    # rest. it also uses @page.title as the first header if no other text
    # is provided.
    my $is_intro = $sec->{is_intro} =
        !$page->{section_n}++ && $enable;
        
    # top-level headers start at h2 when @page.enable.title is true, since the
    # page title is the sole h1. otherwise, h1 is top-level.
    my $l = ($sec->parent->{header_level} || $enable) + 1;
    
    # intro is always h1, max is h6
    $l = 1 if $is_intro;
    $l = 6 if $l > 6;
    
    $sec->{header_level} = $l;
}

sub section_html { _section_html(0, @_) }
sub quote_html   { _section_html(1, @_) }

sub _section_html {
    my ($is_quote, $sec, $page, $el) = @_;

    # clear at end of element.
    $el->configure(clear => 1);
    $el->configure(type  => 'blockquote') if $is_quote;

    # determine if this is the intro section.
    my $l = $sec->{header_level};
    my $is_intro = $sec->{is_intro};
    my $class = $is_intro ? 'section-page-title' : 'section-title';

    # use the page title if no other title is provided and @page.enable.title
    # is true.
    my $title_fmt;
    my $title = $sec->name;
    $title_fmt = $title = $page->get('page.title')
        if $is_intro && !length $title;
    
    # if we have a title and this type of title is enabled.
    if (!$is_quote && length $title) {
        
        # parse text formatting in title
        $title_fmt //= $page->parse_formatted_text($title,
            pos => $sec->create_pos
        );
        
        # meta section may be the heading ID
        my $heading_id = $sec->meta('section');
        
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
            attributes => { id => "wiki-anchor-$heading_id" },
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
            parent      => $sec,
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
    foreach ($sec->content_visible_pos) {
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
    my ($sec, $page, $el) = @_;
    $el->add_class('clear');
}

__PACKAGE__
