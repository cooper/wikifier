# Copyright (c) 2017, Mitchell Cooper
#
# set metadata on the parent block
#
package Wikifier::Block::Meta;

use warnings;
use strict;

use Scalar::Util 'blessed';

our %block_types = (
    meta => {
        base => 'map'
    }
);

__PACKAGE__
