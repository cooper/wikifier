# Copyright (c) 2016, Mitchell Cooper
# a Current object describes the state of the parser
package Wikifier::Parser::Current;

use warnings;
use strict;
use 5.010;

# %current
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
#               check with ->is_escaped. mark with ->mark_escaped
#
#   ignored     true if the character is a master parser character({, }, etc.)
#               these are "ignored" in that if they are escaped they will not be
#               re-escaped for block parsers or the formatting parser.
#               check with ->is_ignored. mark with ->mark_ignored
#
#   comment     true if the character is inside a comment and should be ignored.
#               check with ->is_comment. mark with ->mark_comment
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
#               var_name, var_value, var_no_interpolate

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
sub is_escaped    { shift->{escaped}   }
sub mark_escaped  { shift->{escaped}++ }
sub clear_escaped {
    my $c = shift;
    $c->{escaped}-- if ($c->{escaped} || 0) > 0;
}

# /* block comments */
sub is_comment    { shift->{comment}   }
sub mark_comment  { shift->{comment}++ }
sub clear_comment {
    my $c = shift;
    $c->{comment}-- if ($c->{comment} || 0) > 0;
}

# ignored characters
sub is_ignored    { shift->{ignored}   }
sub mark_ignored  { shift->{ignored}++ }
sub clear_ignored {
    my $c = shift;
    $c->{ignored}-- if ($c->{ignored} || 0) > 0;
}

# the current block
sub block {
    my ($c, $block, $no_catch) = @_;
    return $c->{block} if !$block;
    $c->{block} = $block;
    $c->catch(
        name        => $block->type,
        hr_name     => $block->to_desc,
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

# push content to the current catch
sub push_content {
    my $c = shift;
    my $pos = {
        line => $c->{line},
        col  => $c->{col}
    };
    push @{ $c->{catch}{position} }, $pos for 0..$#_;
    push @{ $c->{catch}{location} }, @_;
}

# return the last element in the current catch
sub last_content {
    my $c = shift;
    return $c->{catch}{location}[-1] = shift if @_;
    return $c->{catch}{location}[-1];
}

# append a string to the last element in the current catch
sub append_content {
    my ($c, @append) = @_;
    foreach my $append (@append) {
        my $catch    = $c->catch or die;
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

# set the current catch
# %opts = (
#   name        type of catch
#   hr_name     human-readable description of the catch, used in warnings/errors
#   location    an array reference to where content will be pushed
#   valid_chars (opt) regex for characters that are allowed in the catch
#   position    (opt) an array reference to where position info will be pushed
#   nested_ok   (opt) true if we should allow the catch elsewhere than top-level
#   parent      (opt) the catch we will return to when this one closes
#   is_block    (opt) true for blocks so that we know to reset $c->block
#   is_toplevel (opt) true only for the main block
# )
sub catch {
    my ($c, %opts) = (shift, @_);
    return $c->{catch} if !@_;

    # there's already a catch, and this is only allowed at the top level
    if ($c->{catch} && !$c->{catch}{is_toplevel} && !$opts{nested_ok}) {
        return $c->error(
            "Attempted to start $opts{hr_name} in the middle of ".
            $c->{catch}{hr_name}
        );
    }

    @opts{'line', 'col'} = @$c{'line', 'col'};
    $opts{position} ||= [];
    $opts{parent}   ||= $c->catch;
    $c->{catch} = \%opts;
    return; # success
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
