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
    $el->{styles}     ||= {};
    
    # content must an array of items.
    $el->{content} //= [];
    $el->{content}   = ref $el->{content} eq 'ARRAY' ? $el->{content} : [ $el->{content} ];
    $el->{container} = 1 if $el->{type} eq 'div';
    
    return $el;
}

# create a child and add to content.
sub create_child {
    my $el    = shift;
    my $child = __PACKAGE__->new(@_);
    $el->add($child);
    return $child;
}

# add a child or text node.
sub add {
    my ($el, $child) = @_;
    $child->{parent} = $el if blessed $child;
    push @{ $el->{content} }, $child;
}

# add a class.
sub add_class {
    push @{ shift->{classes} }, shift;
}

# add an attribute.
sub add_attribute {
    shift->{attributes}{+shift} = shift;
}

# add style.
sub add_style {
    shift->{styles}{+shift} = shift;
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
    
    # quickly determine if this is a container.
    $el->{container} ||= scalar @{ $el->{content} };
    
    # add classes.
    my $classes;
    foreach my $class (@{ $el->{classes} }) {
        $classes .= " wiki-$class" if     defined $classes;
        $classes  = "wiki-$class"  if not defined $classes;
    }
    $html .= " class=\"$classes\"" if defined $classes;
    
    # add styles.
    my $styles;
    foreach my $style (keys %{ $el->{styles} }) {
        $styles ||= '';
        $styles  .= "$style: ".$el->{styles}{$style}.q(; );
    }
    $html .= " style=\"$styles\"" if defined $styles;
    
    # add other attributes.
    foreach my $attr (keys %{ $el->{attributes} }) {
        my $value = encode_entities($el->{attributes}{$attr});
        $html    .= " $attr=\"$value\"";
    }
    $html .= ">\n" if $el->{container};
    
    # add the inner content.
    my $content;
    foreach my $child (@{ $el->{content} }) {
        $content  = '' if not defined $content;
        if (not blessed $child) {
            $content .= Wikifier::Utilities::indent("$child\n");
            next;
        }
        $content .= Wikifier::Utilities::indent($child->generate);
    }
    $html .= $content if defined $content;
    
    # close it off.
    unless ($el->{no_close_tag}) {
        $html .= $el->{container} ? "</$$el{type}>" : ' />';
    }
    
    return "$html\n";
}

sub classes { shift->{classes} }
sub parent  { shift->{parent}  }

1
