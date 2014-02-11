#!/usr/bin/perl
# Copyright (c) 2014, Mitchell Cooper
#
package Wikifier::Element;

use warnings;
use strict;

use HTML::Entities qw(encode_entities);

# create a new page.
sub new {
    my ($class, %opts) = @_;
    $opts{classes}    ||= defined $opts{class} ? [ $opts{class} ] : [];
    $opts{attributes} ||= {};
    $opts{content}    ||= defined $opts{content} ?
                          (ref $opts{content} ? $opts{content} : [ $opts{content} ]) : [];
    $opts{inner}        = 1 if $opts{type} eq 'div';
    return bless \%opts, $class;
}

# create a child and add to content.
sub create_child {
    my $el    = shift;
    my $child = __PACKAGE__->new(@_);
    push @{ $el->{content} }, $child;
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
    
    # add the inner content.
    my $content;
    foreach my $child (@{ $el->{content} }) {
        $content  = '' if not defined $content;
        $content .= "$child\n" and next if not blessed $child;
        $content .= Wikifier::Utilities::indent($child->generate);
    }
    
    # close it off.
    if (defined $content) { $html .= ">\n$content\n</$$el{type}>"           }
    else                  { $html .= $el->{inner} ? "</$$el{type}>" : '/ >' }
    
    return "$html\n";
}

sub classes { shift->{classes} }
sub parent  { shift->{parent}  }

1
