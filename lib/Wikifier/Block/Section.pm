#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
# sections are containers for paragraphs, image boxes, etc., each with a title.
#
package Wikifier::Block::Section;

use warnings;
use strict;

use Scalar::Util 'blessed';

our %block_types = (
    section => {
        parse => \&section_parse,
        html  => \&section_html,
        alias => 'sec'
    },
    clear => {
        html => \&clear_html
    }
);

# this counts how many sections there are.
# this is then compared in section_html to see if it's the last section.
# if it is and last_section_footer is enabled, the </div> is omitted
# in order to leave room for a footer.
sub section_parse {
    my ($block, $page) = @_;
    
    # determine header level.
    $block->{header_level} = ($block->{parent}{header_level} || 1) + 1;

    # track the section count.
    $page->{c_section_n} = -1 if not defined $page->{section_n};
    $page->{section_n}   = -1 if not defined $page->{section_n};

    $page->{section_n}++;
}

sub section_html {
    my ($block, $page, $el) = @_;
    $page->{c_section_n}++;
    
    # clear at end of element.
    $el->configure(clear => 1);
    
    # disable the footer if necessary.
    my $no_footer = $page->wiki_info('enable_section_footer') &&
        $page->{c_section_n} == $page->{section_n};
    $el->configure(no_close_tag => $no_footer);
    
    # determine if this is the intro section.
    my $is_intro = !$page->{c_section_n};
    my $class    = $is_intro ? 'section-page-title' : 'section-title';
    
    # determine the page title if necessary.
    my $title    = $block->{name};
       $title    = $page->get('page.title') if $is_intro && !length $title;
    
    # if we have a title and this type of title is enabled.
    if (length $title and !($is_intro && $page->wiki_info('no_page_title'))) {
    
        # determine the heading level.
        my $l    = $is_intro ? 1 : $block->{header_level};
           $l    = 6 if $block->{header_level} > 6;

        # create the hedding.
        my $heading = Wikifier::Element->new(
            type  => "h$l",
            class => $class
        );
        
        $el->add($heading);
    }
    
}

sub clear_html {
    return '<div class="clear"></div>';
}

__PACKAGE__
