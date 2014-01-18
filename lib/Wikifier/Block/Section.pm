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
        base => 'container',
        html => \&section_html
    }
);

sub section_html {
    my ($block, $page) = (shift, @_);
    $page->{section_n} ||= 0;
    my $string = "<div class=\"wiki-section\">\n";
    
    # determine if this is the intro section.
    my $is_intro = !$page->{section_n}++;
    my $class    = $is_intro ? 'wiki-section-page-title' : 'wiki-section-title';
    
    # determine the page title.
    my $title    = $block->{name};
       $title    = $page->get('page.title') if $is_intro && !length $title;
    
    # if we have a title, and this type of title is enabled.
    if (length $title and !($is_intro && $page->wiki_info('no_page_title'))) {
        $string .= "    <h1 class=\"wiki-section-page-title\">$title</h1>\n";
    }
   
    # append the indented HTML of each contained block.
    foreach my $item (@{$block->{content}}) {
        next unless blessed $item;
        $string .= Wikifier::Utilities::indent($item->html(@_))."\n";
    }
    
    # end the section.
    $string .= "<div class=\"clear\"></div>\n";
    $string .= "</div>\n";
    return $string;
    
}

__PACKAGE__
