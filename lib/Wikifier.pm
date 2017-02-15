# Copyright (c) 2017, Mitchell Cooper
#
# This class represents a wiki language manager.
#
# Typically, this class is not accessed directly. It is used indirectly via a
# Wikifier::Wiki or Wikifier::Page.
#
# The same wikifier instance may be used for several pages. However, the
# wikifier object should not be used for a wiki implementation. For example, an
# HTTPd helper process which manages an entire wiki site would do so by using a
# Wikifier::Wiki. This Wikifier::Wiki would then use the same wikifier object
# for each page, saving the need to reregister blocks, formatting parsers, etc.
#
# On 13 February 2013, the wikifier class was split into several smaller
# packages, and the block loading system was redesigned to require registration
# of block types.
#
#   Parser:         parses a wiki source file, separating it into blocks.
#   Formatter:      parses text formatting such as [b]bolds[/b] and [[links]].
#   BlockManager:   manages creation of block objects, loading of block classes.
#   Utilities:      provides convenience methods used throughout Wikifier.
#
# Whereas before a Wikifier::Page object would store most parser-related
# storage, the wikifier object now has this duty; Wikifier::Page objects
# represent a single page now and has little to do with the actual parser.
# (That makes more sense anyway, right?)
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
use Wikifier::Elements;

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

# create a new wikifier instance.
sub new {
    my ($class, %opts) = @_;
    my $wikifier = bless \%opts, $class;
    return $wikifier;
}

1
