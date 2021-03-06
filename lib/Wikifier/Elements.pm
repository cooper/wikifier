# Copyright (c) 2017, Mitchell Cooper
#
# Encapsulates multiple elements to behave as one, without actually having
# a wrapper element.
#
package Wikifier::Elements;

use warnings;
use strict;
use 5.010;

use Scalar::Util qw(blessed);
use Wikifier::Utilities qw(L);

sub new {
    my ($class, %opts) = @_;
    return bless {
        elements => [],
        contents => [],
        %opts
    }, $class;
}

sub configure {
    my ($els, @opts) = @_;
    $_->configure(@opts) for $els->elements;
}

sub create_child {
    my $els   = shift;
    my $child = Wikifier::Element->new(@_);
    $els->add($child);
    return $child;
}

sub add {
    my ($els, $child) = @_;
    return if !length $child;
    $child->{parent} = $els if blessed $child;
    push @{ $els->{elements} }, $child;
}

sub add_class {
    my ($els, $class) = @_;
    $_->add_class($class) for $els->elements;
}

sub add_attribute {
    my ($els, $attr, $val) = @_;
    $_->add_class($attr, $val) for $els->elements;
}

sub add_style {
    my ($els, $attr, $val) = @_;
    $_->add_style($attr, $val) for $els->elements;
}

sub remove_class {
    my ($els, $class) = @_;
    $_->add_class($class) for $els->elements;
}

sub classes {
    L "Called ->classes on Wikifier::Elements";
    return;
}

sub generate {
    my ($els, $str) = (shift, '');
    return $els->{generated} if defined $els->{generated};
    $str .= $_->generate for $els->elements;
    return $els->{generated} = $str;
}

sub elements    { @{ shift->{elements} }    }
sub parent      { shift->{parent}           }

1
