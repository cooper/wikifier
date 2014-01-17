#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# sections are containers for paragraphs, image boxes, etc., each with a title.
# the one exception is the introductory section, which has no title and does not display
# at all in the article's table of contents.
#
package Wikifier::Block::Section;

use warnings;
use strict;
use feature qw(switch);
use parent 'Wikifier::Block::Container';

sub new {
    my ($class, %opts) = @_;
    $opts{type} = 'section';
    return $class->SUPER::new(%opts);
}

sub _parse {
    my ($block, $page) = (shift, @_);
    
    # increment the current reference prefix.
    $block->{ref_prefix}++; #XXX: references{} takes care of this now.
    
    $block->SUPER::_parse(@_);
}

# HTML.
sub _result {
    my ($block, $page) = (shift, @_);
    $page->{section_n} ||= 0;
    my $string = "<div class=\"wiki-section\">\n";
    
    # regular section.
    if ($page->{section_n}++) {
       $string .= "    <h2 class=\"wiki-section-title\">$$block{name}</h2>\n";
    }
    
    # introduction section.
    else {
       my $title = $page->get('page.title');
       $string .= "    <h1 class=\"wiki-section-page-title\">$title</h1>\n"
       unless $page->wiki_info('no_page_title');
    }
   
    # append the indented HTML of each contained block.
    foreach my $item (@{$block->{content}}) {
        $string .= Wikifier::Utilities::indent($item->result(@_))."\n";
    }
    
    # end the section.
    $string .= "<div class=\"clear\"></div>\n";
    $string .= "</div>\n";
    return $string;
    
}

1
