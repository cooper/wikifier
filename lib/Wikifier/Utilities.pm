# Copyright (c) 2017, Mitchell Cooper
#
# Wikifier::Utilities provides several functions used throughout the wikifier.
# It exports any of the functions as needed.
#
package Wikifier::Utilities;

use warnings;
use strict;
use 5.010;

use Scalar::Util qw(blessed);
use File::Basename qw(fileparse);
use File::Path qw(make_path);

sub import {
    my $package = caller;
    no strict 'refs';
    *{$package.'::'.$_} = \&{__PACKAGE__.'::'.$_} foreach @_[1..$#_];
}

sub L(@);
sub E(@);
sub Lindent(@);
sub Lback(@);

#################
### UTILITIES ###
#################

# Increase indention level by $times indents.
sub indent_str {
    my ($string, $times, $prefix) = @_;
    return undef if !defined $string;
    $times  //= 1;
    $prefix //= '';
    my $space = '    ' x $times;
    my $final_string = '';
    foreach my $line (split "\n", $string) {
        $final_string .= "$prefix$space$line\n";
    }
    return $final_string;
}

my $valid_page_extensions = join '|', qw(page conf model);

# 'Some Article' -> 'some_article.page'
sub page_name {
    my ($page_name, $ext) = @_;
    return undef if !defined $page_name;
    return $page_name->name if blessed $page_name;

    $page_name = page_name_link($page_name);

    # append the extension if it isn't already there.
    if ($page_name !~ m/\.($valid_page_extensions)$/) {
        $ext //= '.page';
        $page_name .= $ext;
    }

    return $page_name;
}

# 'Some Article' -> 'some_article'
# 'Some Article' -> 'Some_Article' (with $no_lc)
sub page_name_link {
    my ($page_name, $no_lc) = @_;
    return undef if !defined $page_name;
    
    # replace non-alphanumerics with _ and lowercase.
    $page_name =~ s/[^\w\.\-\/]/_/g;
    $page_name = lc $page_name unless $no_lc;

    return $page_name;
}

# 'Some Article' -> 'some_article'
# 'some_article.page' -> 'some_article'
sub page_name_ne {
    my $page_name = page_name(shift, '');
    $page_name =~ s/\.($valid_page_extensions)$//;
    return $page_name;
}

# two page names equal?
sub page_names_equal {
    my ($page_name_1, $page_name_2, $ext) = @_;
    return page_name($page_name_1, $ext) eq page_name($page_name_2, $ext);
}

# 'Some Cat' -> 'some_cat.cat'
# 'some_cat' -> 'some_cat.cat'
sub cat_name {
    my $cat_name = page_name_link(@_);

    # append the extension if it isn't already there.
    if ($cat_name !~ m/\.cat$/) {
        $cat_name .= '.cat';
    }

    return $cat_name;
}

# 'Some Cat' -> 'some_cat'
# 'some_cat.cat' -> 'some_cat'
sub cat_name_ne {
    my $cat_name = cat_name(@_);
    $cat_name =~ s/\.cat$//;
    return $cat_name;
}

# make a path if necessary
sub make_dir {
    my ($dir, $name) = @_;
    my (undef, $prefix) = fileparse($name);
    return if $prefix eq '.' || $prefix eq './';
    make_path("$dir/$prefix", { error => \my $err });
    L "mkdir $dir/$prefix: @$err" if @$err;
}

# removes leading and trailing whitespace from a string.
sub trim ($) {
    my $string = shift;
    return undef if !defined $string;
    $string =~ s/^\s*//g;     # remove leading whitespace.
    $string =~ s/\s*$//g;     # remove trailing whitespace.
    return $string;
}

# removes leading and trailing whitespace from a string, returning the
# new string and the number of newlines removed from front and back.
sub trim_count ($) {
    my $string = shift;
    return wantarray ? (undef, 0, 0) : undef if !defined $string;
    my ($front, $back) = (0, 0);
    while ($string =~ s/^(\s+)//) {
        $front += () = $1 =~ /\n/g;
    }
    while ($string =~ s/(\s+)$//) {
        $back += () = $1 =~ /\n/g;
    }
    return wantarray ? ($string, $front, $back) : $string;
}

sub no_length_undef ($) {
    my $str = shift;
    return undef if !length $str;
    return $str;
}

sub no_items_undef ($) {
    my $collection = shift;
    return undef if ref $collection eq 'ARRAY' && !@$collection;
    return undef if ref $collection eq 'HASH'  && !keys %$collection;
    return $collection;
}

sub filter_defined ($) {
    my $hash = shift;
    ref $hash eq 'HASH' or return {};
    my %new;
    foreach my $key (keys %$hash) {
        my $value = $hash->{$key};
        next unless defined $value;
        $new{$key} = $value;
    }
    return \%new;
}

sub filter_nonempty ($) {
    my $hash = shift;
    ref $hash eq 'HASH' or return {};
    my %new;
    foreach my $key (keys %$hash) {
        my $value = $hash->{$key};
        
        # not defined
        next if !defined $value;
        
        # empty arrayref
        next if ref $value eq 'ARRAY' && !@$value;
        
        # empty hashref
        next if ref $value eq 'HASH' && !keys %$value;
        
        # empty string
        next if !ref $value && !length $value;
        
        $new{$key} = $value;
    }
    return \%new;
}

# human-readable truncation
sub truncate_hr {
    my ($string, $max_chars) = @_;
    return undef if !defined $string || !$max_chars;
    return $string if length $string <= $max_chars;
    return substr($string, 0, $max_chars - 3).'...';
}

sub hash_maybe($) {
    my $href = shift;
    return if ref $href ne 'HASH';
    return %$href;
}

sub keys_maybe($) {
    my %hash = hash_maybe(shift);
    return keys %hash;
}

sub values_maybe($) {
    my %hash = hash_maybe(shift);
    return values %hash;
}

### MAP AND LIST VALUES

# after closing a value, trim it and flatten lists
sub fix_value (\$) {
    my $value = shift;
    my @new;
    return if !defined $$value;
    $$value = [$$value] if ref $$value ne 'ARRAY';
    foreach my $item (@$$value) {
        if (blessed $item) {
            push @new, $item;
            next;
        }
        $item =~ s/(^\s*)|(\s*$)//g;
        push @new, $item if length $item;
    }
    $$value = \@new;
    $$value = $new[0] if @new == 1;
    $$value = undef   if !@new;
}

# append either some text or a block to a value
sub append_value (\$@) {
    my ($value, $item, $pos, $startpos) = @_;

    # nothing
    return if !defined $item;

    # first item
    if (ref $$value ne 'ARRAY' || !@$$value) {
        %$startpos = %$pos;
        $$value = [ $item ];
        return;
    }

    # if the last element or the append element are refs, push
    my $last = \$$value->[-1];
    if (ref $$last || ref $item) {
        push @$$value, $item;
        return;
    }

    # otherwise, append as text
    $$last .= $item;
}

# convert blocks to HTML elements and parse formatted text.
sub html_value (\$@) {
    my ($value, $pos, $page, $format_values) = @_;

    # if this is an arrayref, it's a mixture of blocks and text
    my @items = ref $$value eq 'ARRAY' ? @$$value : $$value;

    # handle each item
    my @new;
    foreach my $item (@items) {

        # parse formatted text
        if (!blessed $item && $format_values) {
            $item = $page->parse_formatted_text($item, pos => $pos);
        }

        # convert block to element.
        # this has to come after the above since ->parse_formatted_text()
        # might return a block.
        if (blessed $item) {
            my $their_el = $item->html($page);
            $item = $their_el || "$item";
        }

        push @new, $item;
    }
    $$value = \@new;
    $$value = $new[0] if @new == 1;
    $$value = undef   if !@new;
}

# convert value to human-readable form
sub  hr_value (@) { &_hr_value }
sub _hr_value {
    my @stuff = map {
        my $thing = ref $_ ? $_ : trim($_);
        my $res   =
            ref $thing eq 'ARRAY'                                   ?
                join(' ', grep defined, map _hr_value($_), @$thing)  :
            !length $thing                                          ?
                undef                                               :
            blessed $thing                                          ?
                $thing->hr_desc                                     :
            q(').truncate_hr($thing, 30).q(');
        $res;
    } @_;
    return wantarray ? (@stuff) : $stuff[0];
}

### LOGGING

our $indent = 0;

sub indent () { $indent++ }
sub back   () { $indent-- }

# log.
our @logs;
sub L(@) {
    my @lines = @_;
    foreach my $str (@lines) {
        
        # run code with indentation
        if (ref $str eq 'CODE') {
            indent;
            $str->();
            back;
            next;
        }
        
        # indent line
        chomp $str;
        $str = ('    ' x $indent).$str;
        
        # store last 1000 lines
        push @logs, $str;
        @logs = @logs[-1000..-1] if @logs > 1000;
        
        say STDERR $str;
    }
}

# error.
sub E(@) {
    my @caller = caller 1;
    (my $sub = $caller[3]) =~ s/(.+)::(.+)/$2/;
    my $info = $sub && $sub ne '(eval)' ? "$sub()" : $caller[0];
    return L map "error: $info: $_", @_;
}

# log and then indent.
sub Lindent(@) {
    L shift;
    indent;
    L @_;
}

# go back and then log.
sub Lback(@) {
    back;
    L @_;
}

sub align {
    my ($action, $info) = @_;
    return sprintf '%-10s%s', $action, $info // '';
}

sub notice {
    my ($type, %opts) = @_;
    my $noti = { %opts, type => $type };
    foreach my $sess (values %Wikifier::Server::sessions) {
        # TODO: some notifications should be specific to a wiki
        # TODO: make it possible to subscribe to specific types of notifications
        push @{ $sess->{notifications} }, $noti;
    }
}

1
