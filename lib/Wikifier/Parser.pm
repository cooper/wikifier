# Copyright (c) 2017, Mitchell Cooper
#
# Wikifier::Parser is a function class of wikifier which parses wiki source
# code. This is the master parser; its primary purpose is to divide the file
# into blocks. The content within such blocks is parsed elsewhere by block
# type classes.
#
# This class is never to be used directly. Use $page->parse.
#
package Wikifier::Parser;

use warnings;
use strict;
use 5.010;

use Wikifier::Parser::Current;
use Wikifier::Utilities qw(trim truncate_hr L);
use Scalar::Util qw(blessed);

###############
### PARSING ###
###############

# parse a wiki file.
sub parse {
    my ($wikifier, $page) = @_;

    # use ->{source} or ->path
    my $file = $page->path;
    $file = \$page->{source} if defined $page->{source};

    # no file given
    if (!defined $file) {
        return 'Page does not exist';
    }

    # open the file
    my $fh;
    if (!open $fh, '<', $file) {
        return "Couldn't open '$file': $!";
    }
    binmode $fh, ':encoding(utf8)';

    # set initial parse info
    my $main_block = $page->{main_block};
    my $c = Wikifier::Parser::Current->new;
    $page->{warnings} = $c->{warnings}; # store parser warnings in the page
    $main_block->{current} = $c;        # manually set {current} for main block
    $c->block($main_block);             # set the current block to the main one
    $c->{catch}{is_toplevel}++;         # mark the main block as top-level catch

    # read it line-by-line
    while (my $line = <$fh>) {
        $line =~ s/[\r\n\0]//g;     # remove returns and newlines.
        $c->{line} = $.;
        $wikifier->handle_line($line, $page, $c);
        next if !$c->{error};
        close $fh;
        return $c->{error};
    }

    close $fh;

    # some catch was not terminated
    my $catch = $c->catch;
    if ($catch && $catch->{name} ne 'main') {
        my ($type, $line, $col) = @$catch{ qw(hr_name line col) };
        return "Line $line:$col: $type still open at EOF";
    }

    # run ->parse on the main block
    unless ($page->{vars_only}) {
        $main_block->parse($page);
        return $c->{error} if $c->{error};
    }

    return wantarray ? (undef, $c) : undef;
}

# parse a single line.
sub handle_line {
    my ($wikifier, $line, $page, $c) = @_;
    my @chars = (split(//, $line), "\n");
    CHAR: for my $i (0 .. $#chars) {
        next CHAR if delete $c->{skip_char};
        $c->{col} = $i;
        $c->{next_char} = $chars[$i + 1] // '';
        $wikifier->handle_character($chars[$i], $page, $c);
        return $c->{error} if $c->{error};
    }
    return;
}

my %variable_tokens = map { $_ => 1 } qw(@ % : ; -);

# parse a single character.
# note: never return from this method; instead last from for loop.
sub handle_character {
    my ($wikifier, $char, $page, $c) = @_;
    $c->{char} = $char;

    CHAR:    for ($char) {                      # next CHAR skips default
    DEFAULT: for ($char) {  my $use_default;    # next DEFAULT goes to default

    # before ANYTHING else, check if we are in a brace escape
    if ($c->is_curly) {

        # increase curly count
        my $is_first = delete $c->{curly_first};
        if ($char eq '{' && !$is_first) {
            $c->mark_curly;
        }

        # only ->clear_curly if this is NOT the last curly
        elsif ($char eq '}') {
            $c->clear_curly;
            $c->clear_catch if !$c->is_curly;
        }

        # go to next char if this was the initial or final curly bracket
        next CHAR if $is_first || !$c->is_curly;

        # go to default which will ->append_content to the brace escape catch
        next DEFAULT;
    }

    # comment entrance
    if ($char eq '/' && $c->{next_char} eq '*') {
        $c->mark_comment;
        next CHAR;
    }

    # comment closure
    if ($char eq '*' && $c->{next_char} eq '/') {
        next DEFAULT if !$c->is_comment;
        $c->clear_comment;
        $c->{skip_char}++;
        next CHAR;
    }

    # inside a comment
    next CHAR if $c->is_comment;

    # starts a block
    if ($char eq '{') {
        $c->mark_ignored;
        next DEFAULT if $c->is_escaped;

        # if the next char is @, this is {@some_var}
        my @block_classes;
        my $block_type = my $block_name = '';
        if ($c->{next_char} eq '@') {
            $c->{skip_char}++;
            $block_type = 'variable';
        }

        # otherwise, this is a normal block.
        # we will find the block type and name from the ->last_content
        else {
            my $content = $c->last_content;
            my $in_block_name = my $chars_scanned = 0;

            # no ->last_content? don't waste any more time
            return $c->error("Block has no type")
                if !length $content;

            # scan the text backwards to find the block type and name
            BACKCHAR: while (length(my $last_char = chop $content)) {
                $chars_scanned++;

                # entering block name.
                if ($last_char eq ']') {
                    next BACKCHAR if !$in_block_name++;
                    # if it was at 0, we just entered the block name.
                }

                # exiting block name.
                elsif ($last_char eq '[') {
                    next BACKCHAR if !--$in_block_name;
                    # if it was 1 or more, we're still in it.
                }

                # we are in the block name, so add this character to the front.
                if ($in_block_name) {
                    $block_name = $last_char.$block_name;
                }

                # could this char be part of a block type?

                # it can, so we're probably in the block type at this point.
                # append to the block type.
                elsif ($last_char =~ m/[\w\-\$\.]/) {
                    $block_type = $last_char.$block_type;
                    next BACKCHAR;
                }
                
                # tilde can terminate the block type
                elsif ($last_char eq '~' && length $block_type) {
                    last BACKCHAR;
                }

                # this could be a space between things.
                elsif ($last_char =~ m/\s/ && !length $block_type) {
                    next BACKCHAR;
                }

                # I give up. bail!
                else {
                    $chars_scanned--; # we do not possess this character.
                    last BACKCHAR;
                }
            }

            # overwrite the ->last_content with the title and name stripped out
            $c->last_content(substr($c->last_content, 0, -$chars_scanned));

            # if the block type contains dot(s), it has classes
            ($block_type, @block_classes) = split /\./, $block_type;
        }

        # if no type at this point, assume it's a map. see issue #32
        $block_type = 'map'
            if !length $block_type;

        # if the block type starts with $, it's a model
        my $first = \substr($block_type, 0, 1);
        if ($$first eq '$') {
            $$first = '';
            $block_name = $block_type;
            $block_type = 'model';
        }

        # create a block
        my $block = $wikifier->create_block(
            current => $c,
            line    => $c->{line},
            col     => $c->{col},
            parent  => $c->block,
            type    => $block_type,
            name    => $block_name,
            classes => \@block_classes
        );

        # produce a warning if the block has a name but the type
        # does not support it
        $c->warning($block->hr_type.' does not support block title')
            if length $block_name && !$block->{type_ref}{title};

        # set the block
        $c->block($block);

        # if the next char is {, this is type {{ content }}
        if ($c->{next_char} eq '{') {

            # mark as in a brace escape
            $c->{curly_first}++;
            $c->mark_curly;

            # set the current catch to the brace escape.
            # the content and position are that of the block itself.
            # the parent catch will be the block catch.
            $c->catch(
                name        => 'brace_escape',
                hr_name     => 'brace-escaped '.$block->hr_desc,
                location    => $block->{content},
                position    => $block->{position},
                nested_ok   => 1 # it will always be nested by the block
            ) or next CHAR;
        }
    }

    # closes a block
    elsif ($char eq '}') {
        $c->mark_ignored;
        next DEFAULT if $c->is_escaped;

        # we cannot close the main block.
        if ($c->block->type eq 'main') {
            return $c->error("Attempted to close main block");
        }

        # this is an if statement.
        my @add_contents;
        if ($c->block->type eq 'if') {
            $c->{conditional} = !!_get_conditional($c, $page, $c->block->name);
            @add_contents = $c->content if $c->{conditional};
        }

        # this is an elsif statement.
        elsif ($c->block->type eq 'elsif') {

            # no conditional before this
            return $c->error('Unexpected '.$c->block->hr_desc)
                if !exists $c->{conditional};

            # only evaluate the conditional if the last one was false
            my $before = $c->{conditional};
            if (!$c->{conditional}) {
                $c->{conditional} =
                    !!_get_conditional($c, $page, $c->block->name);
                @add_contents = $c->content if $c->{conditional};
            }
        }

        # this is an else statement.
        elsif ($c->block->type eq 'else') {

            # no conditional before this
            return $c->error('Unexpected '.$c->block->hr_desc)
                if !exists $c->{conditional};

            # title provided
            $c->warning("Conditional on else{} ignored")
                if length $c->block->name;

            # the conditional was false. add the contents of the else.
            @add_contents = $c->content unless delete $c->{conditional};
        }

        # this is {@some_var}
        elsif ($c->block->type eq 'variable') {

            # the variable name may be the block's content.
            # clear the content and set the block name to the variable name
            my $var = length $c->block->name ? $c->block->name : do {
                my $last = $c->last_content;
                $c->clear_content;
                $c->block->{name} = $last;
                $last;
            };

            # find the block; make sure it's a block
            my $block = $page->get($var);
            if (!$block) {
                return $c->error("Variable block \@$var does not exist");
            }
            elsif (!blessed $block || !$block->isa('Wikifier::Block')) {
                return $c->error("Variable \@$var does not contain a block");
            }

            # overwrite the block's parent to the parent of the variable{} block
            $block->{parent} = $c->block->parent;

            # add the block we got from the variable
            @add_contents = $block;
        }

        # normal block. add the block itself.
        else {
            delete $c->{conditional};
            @add_contents = $c->block;
        }

        # close the block.
        # only set the position if it doesn't exist. it may exist already if
        # the block was created in a variable.
        $c->block->{closed}++;
        $c->block->{end_line} //= $c->{line};
        $c->block->{end_col}  //= $c->{col};

        # return to the parent
        $c->clear_catch;
        $c->append_content(@add_contents);
    }

    # ignore backslashes - they are handled later below.
    elsif ($char eq '\\') {
        next DEFAULT if $c->is_escaped;
        next CHAR;
    }

    # if we're at document level, this might be a variable declaration
    elsif ($c->block->type eq 'main' &&
    $variable_tokens{$char} && $c->{last_char} ne '[') {
        $c->mark_ignored;
        next DEFAULT if $c->is_escaped;

        # starts a variable name
        if ($char =~ m/[@%]/ && $c->catch->{is_block}) {

            # disable interpolation if it's %var
            $c->{var_no_interpolate}++ if $char eq '%';

            # negate the value if -@var
            my $prefix = $char;
            if ($c->{last_char} eq '-') {
                $prefix = $c->{last_char}.$prefix;
                $c->{var_is_negated}++;
            }

            # catch the var name
            $c->catch(
                name        => 'var_name',
                hr_name     => 'variable name',
                valid_chars => qr/[\w\.]/,
                skip_chars  => qr/\s/,
                prefix      => [ $prefix, $c->pos ],
                location    => $c->{var_name} = []
            ) or next CHAR;
        }

        # starts a variable value
        elsif ($char eq ':' && $c->catch->{name} eq 'var_name') {
            $c->clear_catch;

            # no length? no variable name
            my $var = $c->{var_name}[-1];
            return $c->error("Variable has no name")
                if !length $var;

            # now catch the value
            $c->{var_is_string}++;
            my $hr_var = truncate_hr($var, 30);
            $c->catch(
                name        => 'var_value',
                hr_name     => "variable \@$hr_var value",
                valid_chars => qr/./s,
                location    => $c->{var_value} = []
            ) or next CHAR;
        }

        # ends a variable name (for booleans) or value
        elsif ($char eq ';' && $c->{catch}{name} =~ m/^var_name|var_value$/) {
            $c->clear_catch;
            my ($var, $val) =
                _get_var_parts(delete @$c{ qw(var_name var_value) });
            my ($is_string, $no_intplt, $is_negated) = delete @$c{qw(
                var_is_string var_no_interpolate var_is_negated
            )};

            # more than one content? not allowed in variables
            return $c->error("Variable can't contain both text and blocks")
                if @$var > 1 || @$val > 1;
            $var = shift @$var;
            $val = shift @$val;

            # no length? no variable name
            return $c->error("Variable has no name")
                if !length $var;

            # string
            if ($is_string && length $val) {
                $val = $wikifier->parse_formatted_text($page, $val)
                    if !$no_intplt && !ref $val;
            }

            # boolean
            elsif (!$is_string) {
                $val = 1;
            }

            # no length and not a boolean.
            # there is no value here
            else {
                undef $val;
            }

            # set the value
            $val = !$val if $is_negated;
            $val = $page->set($var => $val);

            # run ->parse and ->html if necessary
            _parse_vars($page, 'parse', $val);
            _parse_vars($page, 'html',  $val);
        }

        # -@var
        elsif ($char eq '-' && $c->{next_char} =~ m/[@%]/) {
            # do nothing; just prevent the - from making it to default
        }

        # should never reach this, but just in case
        else { $use_default++ }
    }

    else { $use_default++ }
    next CHAR unless $use_default;

    } # End of DEFAULT loop

    # DEFAULT:
    # next DEFAULT goes here

    # at this point, anything that needs escaping should have been handled
    # by now. so, if this character is escaped and reached all the way to
    # here, we will pretend it's not escaped by reinjecting a backslash.
    # this allows further parsers to handle escapes (in particular,
    # the formatting parser.)
    my $append = $char;
    if (!$c->is_ignored && $c->is_escaped) {
        $append = "$$c{last_char}$char";
    }

    # if we have someplace to append this, do that
    if (my $catch = $c->catch) {

        # terminate the catch if the char is in skip_chars,
        if ($catch->{skip_chars} && $char =~ $catch->{skip_chars}) {

            # fetch the stuff that we caught up to this point.
            # also, fetch the prefixes if there are any.
            my @location = @{ $catch->{location} };
            my @position = @{ $catch->{position} };
            if (my $pfx = $catch->{prefix}) {
                my ($prefix, $pos) = @$pfx;
                unshift @location, $prefix;
                unshift @position, $pos;
            }

            # revert to the parent catch, and add our stuff to it
            $c->clear_catch;
            $c->push_content_pos(\@location, \@position);
        }

        # make sure the char is acceptable according to valid_chars
        elsif ($catch->{valid_chars} && $char !~ $catch->{valid_chars}) {
            my $loc = $catch->{location}[-1];
            $char   = "\x{2424}" if $char eq "\n";
            my $err = "Invalid character '$char' in $$catch{hr_name}.";
            $err   .= " Partial: $loc" if length $loc;
            return $c->error($err);
        }

        # append
        $c->append_content($append);
    }

    # nothing to catch! I don't think this can ever happen since the main block
    # is the top-level catch and cannot be closed, but it's here just in case.
    else {
        return $c->error("Nothing to catch $char!");
    }

    } # End of CHAR
    # next CHAR goes here

    #=== Update stuff for next character ===#

    $c->clear_ignored;
    $c->{last_char} = $char;

    # the current character is '\', so set $c->{escaped} for the next
    # character. unless, of course, this escape itself is escaped.
    # (determined with current{escaped})
    if ($char eq '\\' && !$c->is_escaped && !$c->is_curly) {
        $c->mark_escaped;
    }
    else {
        $c->clear_escaped;
    }

    return;
}

# returns an arrayref of parts of an array value, ignoring extra whitespace.
sub _get_var_parts {
    my @new;
    for my $part (@_) {
        if (ref $part ne 'ARRAY') {
            push @new, [];
            next;
        }
        @$part = grep length, map { ref $_ ? $_ : trim($_) } @$part;
        push @new, $part;
    }
    return @new;
}

# recursively call ->parse on the contents of a variable
# consider: this doesn't work for object attributes that don't use ->to_data
sub _parse_vars {
    my ($page, $method, $val) = @_;
    return if !defined $val;

    # this is a block
    if (blessed $val && $val->can($method)) {
        $val->$method($page);
        $val->{is_variable}++;
    }

    # this is a block or something else that has ->to_data
    if (blessed $val && $val->can('to_data')) {
        _parse_vars($page, $method, $val->to_data);
    }

    # hash ref
    if (ref $val eq 'HASH') {
        _parse_vars($page, $method, $_) for values %$val;
    }

    # array ref
    if (ref $val eq 'ARRAY') {
        _parse_vars($page, $method, $_) for @$val;
    }
}

# get the value of a conditional expression
sub _get_conditional {
    my ($c, $page, $conditional) = @_;
    if (!length $conditional) {
        $c->warning('Conditional expression required');
        return;
    }
    if ($conditional =~ /^@([\w\.]+)$/) {
        return $page->get($1);
    }
    my $what = $conditional ? 'true' : 'false';
    $c->warning('Invalid conditional expression; will always be '.$what);
    return;
}

1
