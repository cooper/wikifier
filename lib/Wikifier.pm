#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
# This class represents a wiki language manager.
# The same Wikifier instance may be used for several pages. However, the Wikifier object
# should not be used for a wiki implementation. For example, an HTTPd module which manages
# an entire wiki site would do so by using a Wikifier::Wiki. This Wikifier::Wiki might
# use the same Wikifier object for each page, saving the need to reregister blocks,
# formatting parsers, etc.
#
# This change was made when the Wikifier class was split into several smaller classes and
# the block loading system was redesigned to require registration rather than dynamically
# loading modules as they are needed. This new approach may require more memory, but it
# will be faster and more practical for an HTTPd wiki application.
# 
# Whereas before a Wikifier::Page object would store most parser-related storage, the
# Wikifier object now has this duty; Wikifier::Page objects represent a single page now.
# (That makes more sense anyway, right?)
#
# As of this change that was implemented on February 13, 2013,
# this class is based upon several subclasses which each have different functions:
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
use 5.010;
use parent qw(Wikifier::Parser Wikifier::BlockManager Wikifier::Formatter);

use Wikifier::Parser;
use Wikifier::Formatter;
use Wikifier::BlockManager;
use Wikifier::Utilities;

use Wikifier::Page;
use Wikifier::Block;
use Wikifier::Element;

our $indent = 0;

# create a new wikifier instance.
sub new {
    my ($class, %opts) = @_;
    my $wikifier = bless \%opts, $class;
    return $wikifier;
}

# log.
sub l($) {
    my $str = shift;
    $str = ('    ' x $indent).$str;
    say $str;
}

# log and then indent.
sub lindent($) {
    l(shift);
    indent();
}

# go back and then log.
sub lback($) {
    back();
    l(shift);
}

sub indent () { $indent++ }
sub back   () { $indent-- }

1
