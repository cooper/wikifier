# Copyright (c) 2016, Mitchell Cooper
# a Current object describes the state of the parser
package Wikifier::Parser::Current;

use warnings;
use strict;
use 5.010;

# %current      (ALSO UPDATE parsing.md)
#
#   char        current character
#
#   next_char   next character or an empty string if this is the last one
#
#   last_char   previous character or an empty string if this is the first one
#
#   skip_char   character parser may set this to a true value at any point,
#               which results in the next character being skipped entirely.
#               currently this is used only for the closing '/' in comments
#
#   catch       current catch, represented by a hashref of options. a catch
#               describes the location to where content will be pushed. see the
#               ->catch method for a list of options and what they mean.
#               fetch with ->catch
#
#   block       current block object
#
#   line        current line number
#
#   col         current column number (actually column + 1)
#
#   escaped     true if the current character was escaped (last character = \)
#               check   ->is_escaped
#               mark    ->mark_escaped
#               clear   ->clear_escaped
#
#   ignored     true if the character is a master parser character({, }, etc.)
#               these are "ignored" in that if they are escaped they will not be
#               re-escaped for block parsers or the formatting parser.
#               check   ->is_ignored
#               mark    ->mark_ignored
#               clear   ->clear_ignored
#
#   comment     true if the character is inside a comment and should be ignored.
#               check   ->is_comment
#               mark    ->mark_comment
#               clear   ->clear_comment
#
#   curly       if 1 or greater, this block treats curly brackets inside as
#               text because the block was written as type{{ content }}. this
#               value is the current number of unmatched opening curly brackets.
#               check   ->is_curly
#               mark    ->mark_curly
#               clear   ->clear_curly
#
#   warnings    an array reference to which parser warnings are pushed. this
#               will later be copied to $page->{warnings} and will be included
#               in the display result for pages.
#               produce warnings with ->warning($msg)
#
#   error       parser error message. this is checked after each character. if
#               it is present, parsing is aborted; ->parse() returns the error.
#               produce errors with ->error($msg)
#
#   (others)    these contain partial data until the end of a catch:
#               var_name, var_value, var_no_interpolate, var_is_string,
#               var_is_negated, curly_first

sub new {
    my ($class, %opts) = @_;
    return bless {
        warnings    => [],
        next_char   => '',
        last_char   => '',
        %opts
    }, $class;
}

# escaped characters
sub is_escaped      { &_is      }
sub mark_escaped    { &_mark    }
sub clear_escaped   { &_clear   }

# /* block comments */
sub is_comment      { &_is      }
sub mark_comment    { &_mark    }
sub clear_comment   { &_clear   }

# ignored characters
sub is_ignored      { &_is      }
sub mark_ignored    { &_mark    }
sub clear_ignored   { &_clear   }

# { curly brackets }
sub is_curly        { &_is      }
sub mark_curly      { &_mark    }
sub clear_curly     { &_clear   }

# incremental markers
sub _is     { my ($c, $w) = &_what; $c->{$w} && $c->{$w} > 0                }
sub _mark   { my ($c, $w) = &_what; $c->{$w}++                              }
sub _clear  { my ($c, $w) = &_what; $c->{$w}-- if ($c->{$w} || 0) > 0       }
sub _what   { my ($w) = (caller 2)[3] =~ m/([^_\W]+)$/; return ($_[0], $w)  }

# the current block
sub block {
    my ($c, $block, $no_catch) = @_;
    return $c->{block} if !$block;
    $c->{block} = $block;
    $c->catch(
        name        => $block->type,
        hr_name     => $block->hr_desc,
        location    => $block->{content}  ||= [],
        position    => $block->{position} ||= [],
        is_block    => 1,
        nested_ok   => 1
    ) unless $no_catch;
    return $block;
}

# return the content of the current block
sub content {
    my $c = shift;
    return @{ $c->{block}{content} };
}

# returns the current position
sub pos : method {
    my $c = shift;
    return {
        line => $c->{line},
        col  => $c->{col}
    };
}

# push content to the current catch at the given positions
sub push_content_position {
    my ($c, $contents, $positions) = @_;
    if ($#$contents > $#$positions) {
        warn '->push_contents(): Not enough positions!';
        my $last_pos = $positions->[-1] // $c->pos;
        push @$positions, $last_pos for $#$positions .. $#$contents;
    }
    elsif ($#$positions > $#$contents) {
        warn '->push_contents(): Too many positions!';
        @$positions[ $#$contents .. $#$positions ] = ();
    }
    push @{ $c->{catch}{position} }, @$positions;
    push @{ $c->{catch}{location} }, @$contents;
}

# push content to the current catch at the current position
sub push_content {
    my ($c, @contents) = @_;
    my $pos = $c->pos;
    $c->push_content_position(\@contents, [ ($pos) x @contents ]);
}

# return the last element in the current catch
sub last_content {
    my $c = shift;
    return $c->{catch}{location}[-1] = shift if @_;
    return $c->{catch}{location}[-1];
}

# append content to the last element in the current catch, or call
# ->push_content if we need to add additional elements.
# @append may be any combination of strings and blocks
sub append_content {
    my ($c, @append) = @_;
    foreach my $append (@append) {
        my $catch    = $c->catch;
        my $location = $catch->{location};

        # if it's a block, push.
        # if the location is empty, this is the first element, so push.
        # if the previous element is a ref, push, as this is a new text node.
        if (ref $append || !@$location || ref $location->[-1]) {
            $c->push_content($append);
            next;
        }

        $location->[-1] .= $append;
    }
}

# clear the content of the current catch
sub clear_content {
    my $catch = shift->catch;
    @{ $catch->{location} } = [];
    @{ $catch->{position} } = [];
}

# set the current catch
# see doc/parsing.md for options
sub catch {
    my ($c, %opts) = (shift, @_);
    return $c->{catch} if !@_;

    # there's already a catch, and this is only allowed at the top level
    if ($c->{catch} && !$c->{catch}{is_toplevel} && !$opts{nested_ok}) {
        $c->error(
            "Attempted to start $opts{hr_name} in the middle of ".
            $c->{catch}{hr_name}
        );
        return; # failure
    }

    @opts{'line', 'col'} = @$c{'line', 'col'};
    $opts{position} ||= [];
    $opts{parent}   ||= $c->catch;
    $c->{catch} = \%opts;
    return 1; # success
}

# set the catch back to the parent
sub clear_catch {
    my $c = shift;
    $c->block($c->block->parent, 1) if $c->{catch}{is_block};
    $c->{catch} = delete $c->{catch}{parent};
}

# position info for warnings and errors
sub line_info {
    my $c    = shift;
    my $line = delete $c->{temp_line} // $c->{line};
    my $col  = delete $c->{temp_col}  // $c->{col};
    $line    = defined $line ? "Line $line:" : '';
    $line   .= "$col:" if defined $col;
    $line   .= ' ' if length $line;
    return $line;
}

# parser warning at current position
sub warning {
    my ($c, $warn) = @_;
    $warn = $c->line_info.$warn;
    push @{ $c->{warnings} }, $warn;
    return $warn;
}

# parser fatal error at current position
sub error {
    my ($c, $err) = @_;
    return $c->{error} = $c->line_info.$err;
}

1
