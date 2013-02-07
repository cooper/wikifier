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

# parse(): inherited from hash.

sub result {
    my ($block, $page) = @_;
    my $string = "<div class=\"wiki-infobox\">\n";
    
    # if an image is present, display it.
    if (my $image = $block->{hash}{-image}) {
        my $imagehtml = $image->result();
        $string .= "    <div class=\"wiki-infobox-image-container\">$imagehtml</div>\n";
    }
    
    # start table.
    $string   .= "    <table class=\"wiki-infobox-table\">\n";
    
    # append each pair.
    foreach my $key (keys %{$block->{hash}}) {
        my $value = $block->{hash}{$key};
        
        # special pair - ignore it.
        if (substr($key, 0, 1) eq '-') {
            next;
        }
        
        # value is a block. generate the HTML for it.
        if (blessed $value) {
            $value = $value->result();
        }
        
        # Parse formatting in the value.
        else {
            $value = $page->wikifier->parse_formatted_text($value);
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
