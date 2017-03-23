# Copyright (c) 2017, Mitchell Cooper
#
# sections are containers for paragraphs, image boxes, etc., each with a title.
#
package Wikifier::Block::Section;

use warnings;
use strict;

use Scalar::Util qw(blessed);
use Wikifier::Utilities qw(trim);

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

# this counts how many sections there are.
# this is then compared in section_html to see if it's the last section.
# if it is and page.enable.footer is enabled, the </div> is omitted
# in order to leave room for a footer.
sub section_parse {
    my ($block, $page) = @_;

    # determine header level.
    $block->{header_level} = ($block->parent->{header_level} || 1) + 1;

    $page->{section_n}++;
}

sub section_html {
    my ($block, $page, $el) = @_;

    # clear at end of element.
    $el->configure(clear => 1);

    # determine if this is the intro section.
    my $is_intro = !$page->{c_section_n}++;
    my $class    = $is_intro ? 'section-page-title' : 'section-title';

    # determine the heading level.
    my $l = $is_intro ? 1 : $block->{header_level};
       $l = 6 if ($block->{header_level} || 0) > 6;

    # disable the footer if necessary.
    # this only works if the section is the last item in the main block.
    # FIXME: this needs to be somewhere other than here, since pages might
    # not have a section or might not end with a section
    if ($page->page_opt('page.enable.footer') &&
    $page->{wikifier}{main_block}{content}[-1] == $block) {
        $el->configure(no_close_tag => 1);
        $block->parent->element->configure(no_close_tag => 1);
    }

    # determine the page title if necessary.
    my $title = $block->name;
       $title = $page->get('page.title') if $is_intro && !length $title;

    # if we have a title and this type of title is enabled.
    if (length $title and $is_intro ? $page->page_opt('page.enable.title') : 1) {

        # create the heading.
        my $heading = Wikifier::Element->new(
            type      => "h$l",
            class     => $class,
            content   => $title,
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
