#
# Copyright (c) 2014, Mitchell Cooper
#
# Version control methods.
#
package Wikifier::Revision;

use warnings;
use strict;

use Wikifier;

# add to a revision
sub rev_add (@) {
    my @files = _filify(@_);
}

# remove from a revision
sub rev_rm (@) {
    
}

# commit a revision
sub rev_commit (@) {
    
}

# convert objects to file paths.
sub _filify {
    my @objects_and_files = @_;
    my @paths;
    foreach my $thing (@objects_and_files) {
        my $path = $thing;
        $path = _path($thing) if blessed $thing;
        push @paths, $path;
    }
    return @paths;
}

sub _path {
    my $thing = shift;
    return $thing->path;
}

1
