# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Element;

use warnings;
use strict;
use 5.010;

use Scalar::Util qw(blessed);
use HTML::Entities qw(encode_entities);
use Wikifier::Utilities qw(indent_str);

our %identifiers;

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
    $el->{attributes} ||= {};
    $el->{styles}     ||= {};
    $el->{ids}        ||= \%identifiers;

    # classes
    my @classes;
    push @classes, delete $el->{class}
        if defined $el->{class};            # primary class
    push @classes, @{ $el->{classes} }
        if ref $el->{classes} eq 'ARRAY';   # additional classes
    $el->{classes} = \@classes;

    # create an ID based on the primary class
    if (!length $el->{id}) {
        my $it = $el->{classes}[0] || 'generic';
        my $id = $el->{ids}{$it}++;
        $el->{id} = "$it-$id";
    }

    # content must an array of items.
    $el->{content} = defined $el->{content} ? (
            ref $el->{content} eq 'ARRAY'   ?
            $el->{content}                  :
            [ $el->{content} ]
        ) : [];

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
    return if !length $child;
    $child->{parent} = $el if blessed $child;
    push @{ $el->{content} }, $child;
}

# add a class.
sub add_class {
    push @{ shift->{classes} }, shift;
}

# add an attribute.
sub add_attribute {
    my ($el, $attr, $val) = @_;
    $el->{attributes}{$attr} = $val;
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
    my $el = shift;
    return $el->{generated} if defined $el->{generated};
    my $html = "<$$el{type}";

    # quickly determine if this is a container.
    $el->{container} ||= scalar @{ $el->{content} };

    # add classes.
    my $classes = '';
    push @{ $el->{classes} }, $el->{id} if $el->{need_id};
    foreach my $class (@{ $el->{classes} }) {
        $classes .= "wiki-$class ";
    }
    chop $classes;
    $html .= " class=\"$classes\"" if length $classes;

    # add styles.
    my $styles;
    foreach my $style (keys %{ $el->{styles} }) {
        $styles ||= '';
        $styles  .= "$style: ".$el->{styles}{$style}.'; ';
    }
    $html .= " style=\"$styles\"" if defined $styles;

    # add other attributes.
    foreach my $attr (keys %{ $el->{attributes} }) {
        my $val = $el->{attributes}{$attr};
        next if !defined $val;
        my $value = encode_entities($val);
        $html    .= " $attr=\"$value\"";
    }
    $html .= ">\n" if $el->{container};

    # add the inner content.
    my $content;
    my $prefix = $el->{no_indent} ? "\t\t\t" : '';
    foreach my $child (@{ $el->{content} }) {
        $content  = '' if not defined $content;
        if (not blessed $child) {
            $content .= indent_str("$child\n", 1, $prefix);
            next;
        }
        $content .= indent_str($child->generate, 1, $prefix);
    }
    $html .= $content if defined $content;

    # close it off.
    unless ($el->{no_close_tag}) {
        $html .= $el->{container} ? "</$$el{type}>" : ' />';
    }
    
    return $el->{generated} = "$html\n";
}

sub classes { @{ shift->{classes} || [] } }
sub parent  { shift->{parent} }

1
