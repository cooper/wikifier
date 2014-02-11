#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
package Wikifier::Element;

use warnings;
use strict;

use Scalar::Util qw(blessed);
use HTML::Entities qw(encode_entities);

# create a new page.
sub new {
    my ($class, %opts) = @_;
    my $el = bless \%opts, $class;
    return $el->configure;
}

# options.
sub configure {
    my ($el, %opts) = @_;
    $el->{$_} = $opts{$_} foreach keys %opts;
    $el->{type}       ||= 'div';
    $el->{classes}    ||= defined $el->{class} ? [ $el->{class} ] : [];
    $el->{attributes} ||= {};
    $el->{content}    ||= defined $el->{content} ?
                          (ref $el->{content} ? $el->{content} : [ $el->{content} ]) : [];
    $el->{inner}        = 1 if $el->{type} eq 'div';
    return $el;
}

# create a child and add to content.
sub create_child {
    my $el    = shift;
    my $child = __PACKAGE__->new(@_);
    $el->add($child);
}

# add a child or text node.
sub add {
    push @{ shift->{content} }, shift;
}

# add a class.
sub add_class {
    push @{ shift->{classes} }, shift;
}

# remove a class.
sub remove_class {
    my ($el, $remove) = @_;
    my @classes;
    foreach my $class (@{ $el->{classes} }) {
        push @classes, $class if $class ne $remove;
    }
    $el->{classes} = \@classes;
}

# generate HTML.
sub generate {
    my $el   = shift;
    my $html = "<$$el{type}";
    
    # add classes.
    my $classes;
    foreach my $class (@{ $el->{classes} }) {
        $classes .= " wiki-$class" if     defined $classes;
        $classes  = "wiki-$class"  if not defined $classes;
    }
    $html .= " class=\"$classes\"" if defined $classes;
    
    # add other attributes.
    foreach my $attr (keys %{ $el->{attributes} }) {
        my $value = encode_entities($el->{attributes}{$attr});
        $html    .= " $attr=\"$value\"";
    }
    $html .= ">\n";
    
    # add the inner content.
    my $content;
    foreach my $child (@{ $el->{content} }) {
        $content  = '' if not defined $content;
        $content .= "$child\n" and next if not blessed $child;
        $content .= Wikifier::Utilities::indent($child->generate);
    }
    $html .= $content if defined $content;
    
    # close it off.
    unless ($el->{no_close_tag}) {
        $html .= $el->{inner} ? "</$$el{type}>" : '/ >';
    }
    
    return "$html\n";
}

sub classes { shift->{classes} }
sub parent  { shift->{parent}  }

1
