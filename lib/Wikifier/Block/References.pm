#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# references{} displays a list of citations and sources.
#
package Wikifier::Block::References;

use warnings;
use strict;
use feature qw(switch);
use parent 'Wikifier::Block::Hash';

use Scalar::Util 'blessed';

sub new {
    my ($class, %opts) = @_;
    $opts{type} = 'references';
    
    # book subblock.
    $opts{subblocks}{book} = {
        type    => 'book',
        base    => 'Wikifier::Block::Hash',
        result  => \&_book_result
    };
    
    # webpage subblock.
    $opts{subblocks}{webpage} = {
        type    => 'book',
        base    => 'Wikifier::Block::Hash',
        result  => \&_webpage_result
    };
    
    return $class->SUPER::new(%opts);
}

sub _result {
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
            $value = $value->result(@_);
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

#####################
### BOOK SUBBLOCK ###
#####################

sub _book_result {
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

########################
### WEBPAGE SUBBLOCK ###
########################

sub _webpage_result {
    my ($block, $page) = (shift, @_);
    my %h = %{$block->{hash}};
    my $accessed = $h{accessed} || q();
    return qq{"$h{title}" <a href="$h{url}">$h{url}</a>. $accessed};    
}

1
