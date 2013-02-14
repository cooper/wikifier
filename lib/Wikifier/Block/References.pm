#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# Wikifier::Block::References
#
# This file provides reference and citation functionality.
#
# references{} is used to cite information sources for each section{}.
#   -book{} represents a book source.
#   -webpage{} represents a WWW source.
#
# references-section{} displays a section of references at the end of a page.
#
# Formatting type [<number>] (i.e. [1]) links to a reference in a references-section{}.
#
package Wikifier::Block::References;

use warnings;
use strict;
use feature qw(switch);
use parent 'Wikifier::Block::Hash';

use Scalar::Util 'blessed';

# register block and formatting types to Wikifier. this is called only once per Wikifier.
# in other words, this should not be used for anything relating to a specific page. It is
# intended to be used for registering block and formatting types to the Wikifier object.
sub register {
    my $wikifier = shift;
    
    # register references{}
    $wikifier->register_block(
        type  => 'references',      # name of type
        new   => \&_references_new, # constructor; defaults to \&Wikifier::Block::new
        base  => 'hash',            # parser method will be called on this type first
      # parse => none,              # parser method
        html  => \&_references_html # HTML generation method
    ) or return;
    
    # register -book{}
    $wikifier->register_block(
        type => 'references-book',
        base => 'hash',
        html => \&_book_html
    ) or return;
    
    # register -webpage{}
    $wikifier->register_block(
        type => 'references-webpage',
        base => 'hash',
        html > \&_webpage_html
    ) or return;
    
    # register references-section{}
    $wikifier->register_block(
        type => 'references-section',
        base => 'section',              # for the most part, this has no meaning
        html => \&_section_html
    }) or return;
    
    # register [#] formatting
    $wikifier->register_format(
        type     => 'citation',     # short name for the format type
      # regex    => qr//,           # regex comparison
      # string   => '',             # string comparison
        function => \&Scalar::Util::looks_like_number # function checker
    ) or return;
    
    return 1;
}

# This is called before the parsing of each page. It allows this class to set any options
# that may be needed during the parsing which will immediately follow.
sub init {
    my $page = shift;
    $page->{ref_prefix}   = 0;      # incremented for each reference{} block.
    $page->{auto_ref}   ||= 'a';    # used for automatic image citations.
}


####################
### references{} ###
####################

# create a new references{} block.
sub _references_new {
    my ($class, %opts) = @_;
    my $block = $class->SUPER::new(%opts);
    
    $block->{type} = 'references';
    
    return $block;
}

# reference blocks display nothing.
sub _references_html {
    return q();
}

##########################
### references-books{} ###
##########################

sub _book_html {
    my ($block, $page) = (shift, @_);
    my %h = %{$block->{hash}};
    
    # Last, First (year).
    my $author = $h{author};
    $author   .= qq| ($h{year})| if $h{year};

    # (pagenum).
    my $pagenum = q();
    $pagenum   .= qq| ($h{page})| if $h{page};

    return qq{$author. <span style="font-style: italic;">$h{title}</span>$pagenum};    
}

############################
### references-webpage{} ###
############################

sub _webpage_html {
    my ($block, $page) = (shift, @_);
    
    # accessed date?
    my %h        = %{$block->{hash}};
    my $accessed = q(Accessed ).$h{accessed} || q();
    
    return qq{"$h{title}" <a href="$h{url}">$h{url}</a>. $accessed};    
}

############################
### references-section{} ###
############################

sub _section_html {
    my ($block, $page) = (shift, @_);
    
    my $string = qq{<ul class="wiki-references">\n};
    my @pairs  = (@{$block->{hash_array}}, @{$page->{references}});
    
    # append each reference.
    foreach my $pair (@pairs) {
        my ($key, $value) = @$pair;
        
        # special pair - ignore it.
        if (substr($key, 0, 1) eq '-') {
            next;
        }
        
        # value is a block. generate the HTML for it.
        if (blessed $value) {
            $value = $value->html(@_);
        }
        
        # Parse formatting in the value.
        else {
            $value = $page->parse_formatted_text($value);
        }
        
        # append table row.
        $string .= <<END;
    <li class="wiki-ref-item"><a class="wiki-ref-anchor" name="wiki-ref-$key">
        <span class="wiki-ref-key">$key.</span> $value.
    </a></li>        
END
    }
    
    $string .= qq{</ul>\n};
    return $string;
}

1
