#!/usr/bin/perl
# Copyright (c) 2013, Mitchell Cooper
#
# This class represents a wiki language manager.
# This class is based upon several subclasses which each have different functions:
#
#   Parser:         parses a wiki language file, separating it into individual blocks.
#   Formatter:      parses text formatting such as [b] and [i] formatting.
#   BlockManager:   manages creation of block objects, loading of block classes, etc.
#
# Additionally, this class formerly provided several utilities used throughout the
# Wikifier. Now, these utilities are provided by Wikifier::Utilities.
#
# Typically, this class is not accessed directly. It is used indirectly via a
# Wikifier::Wiki or Wikifier::Page. The Wikifier class is for internal use only.
#
package Wikifier;

use warnings;
use strict;
use feature qw(switch);
use parent qw(Wikifier::Parser Wikifier::Formatter Wikifier::BlockManager);

use Wikifier::Parser;
use Wikifier::Formatter;
use Wikifier::BlockManager;
use Wikifier::Utilities;

use Wikifier::Page;
use Wikifier::Block;

# create a new wikifier instance.
# Required options:
#   file: the location of the file to be read.
sub new {
    my ($class, %opts) = @_;
    my $wikifier = bless \%opts, $class;
    
    # create the main block.
    $wikifier->{main_block} = my $main_block = $wikifier->create_block(
        type   => 'main',
        parent => undef     # main block has no parent.
    );
    
    # initial current hash.
    $wikifier->{current} = {
        block => $main_block 
    };
    
    # initial last hash.
    $wikifier->{last} = {
        block => undef      # main block has no parent.
    };
    
    return $wikifier;
}

1
