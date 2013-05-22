#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# infoboxes display a titled box with an image and table of information.
#
package Wikifier::Block::Infobox;

use warnings;
use strict;
use feature qw(switch);
use parent 'Wikifier::Block::Hash';

use Scalar::Util 'blessed';

sub new {
    my ($class, %opts) = @_;
    $opts{type} = 'infobox';
    return $class->SUPER::new(%opts);
}

sub _result {
    my ($block, $page) = (shift, @_);
    my $string = "<div class=\"wiki-infobox\">\n";
    
    # display the title if it exists.
    if (defined $block->{title}) {
        $string .= "    <div class=\"wiki-infobox-title\">$$block{title}</div>\n";
    }
    
    # if an image is present, display it.
    if (my $image = $block->{hash}{-image}) {
        my $imagehtml = $image->result(@_);
        $imagehtml = Wikifier::Utilities::indent($imagehtml, 2);
        $string .= "    <div class=\"wiki-infobox-image-container\">\n$imagehtml    </div>\n";
    }
    
    # start table.
    $string .= "    <table class=\"wiki-infobox-table\">\n";
    
    # append each pair.
    foreach my $pair (@{$block->{hash_array}}) {
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
        $string .= <<END

        <tr class="wiki-infobox-pair">
            <td class="wiki-infobox-key">$key</td>
            <td class="wiki-infobox-value">$value</td>
        </tr>
        
END
;

    }
    
    $string .= "    </table>\n</div>\n";
    return $string;
}

1
