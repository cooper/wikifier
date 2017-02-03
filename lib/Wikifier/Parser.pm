# Copyright (c) 2016, Mitchell Cooper
#
# Wikifier::Parser is a function class of Wikifier which parses a wiki file.
# The parser separates the file into block types and then passes those to
# Wikifier::BlockManager for block class loading and object creation.
#
# This class is never to be used on its own. You must use Wikifier::Wiki for a
# high-level Wiki manager or the medium-level Wikifier::Page for managing a
# single page.
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

    # no file given.
    if (!defined $file) {
        return "No file specified for parsing";
    }

    # open the file.
    my $fh;
    if (!open $fh, '<', $file) {
        return "Couldn't open '$file': $!";
    }

    # set initial parse info
    my $main_block = $page->{main_block};
    my $c = Wikifier::Parser::Current->new;
    $page->{warnings} = $c->{warnings}; # store parser warnings in the page
    $main_block->{current} = $c;        # manually set {current} for main block
    $c->block($main_block);             # set the current block to the main one
    $c->{catch}{is_toplevel}++;         # mark the main block as top-level catch

    # read it line-by-line.
    while (my $line = <$fh>) {
        $line =~ s/[\r\n\0]//g;     # remove returns and newlines.
        $line = trim($line);        # remove prefixing and suffixing whitespace.
        $c->{line} = $.;
        $wikifier->handle_line($line, $page, $c);
        next if !$c->{error};
        close $fh;
        return $c->{error};
    }

    close $fh;

    # some catch was not terminated.
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

my %variable_tokens = map { $_ => 1 } qw(@ % : ;);

# parse a single character.
# note: never return from this method; instead last from for loop.
sub handle_character {
    my ($wikifier, $char, $page, $c) = @_;

    # set current character.
    $c->{char} = $char;

    CHAR:    for ($char) {
    DEFAULT: for ($char) {  my $use_default;

    # comment entrance and closure.
    if ($char eq '/' && $c->{next_char} eq '*') {
        next DEFAULT if $c->is_escaped;
        $c->mark_comment;
        next CHAR;
    }
    if ($char eq '*' && $c->{next_char} eq '/') {
        next DEFAULT if !$c->is_comment;
        $c->clear_comment;
        $c->{skip_char}++;
        next CHAR;
    }

    # inside a comment.
    next CHAR if $c->is_comment;

    # left bracket indicates the start of a block.
    if ($char eq '{') {
        $c->mark_ignored;
        next DEFAULT if $c->is_escaped;

        # now we must remove the new block type from the
        # current block's last content element.

        # set some initial variables for the loop.
        my $content       = $c->last_content;
        my $block_type    = my $block_name    = '';
        my $in_block_name = my $chars_scanned = 0;

        # no ->last_content?
        return $c->error("Block has no type")
            if !length $content;

        # chop one character at a time from the end of the content.
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

        #
        # remove the block type and name from the current block's content.
        #
        # note: it is very likely that a single space will remain, but this will
        # later be trimmed out by a further cleanup.
        #
        $c->last_content(substr($c->last_content, 0, -$chars_scanned));

        # if the block type contains dot(s), it has classes.
        ($block_type, my @block_classes) = split /\./, $block_type;

        # check a second time, now that we've extracted classes
        return $c->error("Block has no type")
            if !length $block_type;

        # if the block type starts with $, it's a model.
        my $first = \substr($block_type, 0, 1);
        if ($$first eq '$') {
            $$first = '';
            $block_name = $block_type;
            $block_type = 'model';
        }

        # create the new block.
        $c->block($wikifier->create_block(
            current => $c,
            line    => $c->{line},
            col     => $c->{col},
            parent  => $c->block,
            type    => $block_type,
            name    => $block_name,
            classes => \@block_classes
        ));
    }

    # right bracket indicates the closing of a block.
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
            my $conditional = $c->block->name;

            # variable.
            if ($conditional =~ /^@([\w.]+)$/) {
                $conditional = $page->get($1);
            }
            else {
                $c->warning('Invalid conditional expression');
            }

            # add everything from within the if block IF conditional is true.
            @add_contents = $c->content if $conditional;
            $c->{conditional} = !!$conditional;
        }

        # this is an else statement.
        elsif ($c->block->type eq 'else') {
            $c->warning("Conditional on else{} ignored")
                if length $c->block->name;

            # the conditional was false. add the contents of the else.
            @add_contents = $c->content unless $c->{conditional};
        }

        # normal block. add the block itself.
        else {
            @add_contents = $c->block;
        }

        # close the block
        $c->block->{closed}++;
        $c->block->{end_line} = $c->{line};
        $c->block->{end_col}  = $c->{col};

        # return to the parent
        $c->clear_catch;
        $c->append_content(@add_contents);
    }

    # ignore backslashes - they are handled later below.
    elsif ($char eq '\\') {
        next DEFAULT if $c->is_escaped;
        next CHAR;
    }

    elsif ($c->block->type eq 'main' && $variable_tokens{$char}) {
        $c->mark_ignored;
        next DEFAULT if $c->is_escaped;

        # starts a variable name
        if ($char =~ m/[@%]/ && $c->catch->{is_block}) {
            $c->catch(
                name        => 'var_name',
                hr_name     => 'variable name',
                valid_chars => qr/[\w\.]/,
                location    => $c->{var_name} = []
            ) and next CHAR;
            $c->{var_no_interpolate}++ if $char eq '%';
        }

        # starts a variable value
        elsif ($char eq ':' && $c->catch->{name} eq 'var_name') {
            $c->clear_catch;

            # no length? no variable name
            my $var = $c->{var_name}[-1];
            return $c->error("Variable has no name")
                if !length $var;

            # now catch the value
            my $hr_var = truncate_hr($var, 30);
            $c->catch(
                name        => 'var_value',
                hr_name     => "variable \@$hr_var value",
                valid_chars => qr/./s,
                location    => $c->{var_value} = []
            ) and next CHAR;
        }

        # ends a variable name (for booleans) or value
        elsif ($char eq ';' && $c->{catch}{name} =~ m/^var_name|var_value$/) {
            $c->clear_catch;
            my ($var, $val) =
                _get_var_parts(delete @$c{'var_name', 'var_value'});

            # more than one content? not allowed in variables
            return $c->error("Variable can't contain both text and blocks")
                if @$var > 1 || @$val > 1;
            $var = shift @$var;
            $val = shift @$val;

            # no length? no variable name
            return $c->error("Variable has no name")
                if !length $var;

            # string
            if (length $val) {
                $val = $wikifier->parse_formatted_text($page, $val, 0, 0, 1)
                if !delete $c->{var_no_interpolate} && !ref $val;
            }

            # boolean
            else { $val = 1 }

            # set the value
            $val = $page->set($var => $val);

            # run ->parse and ->html if necessary
            _parse_vars($page, 'parse', $val);
            _parse_vars($page, 'html',  $val);
        }

        # should never reach this, but just in case
        else { $use_default++ }
    }

    else { $use_default++ }
    next CHAR unless $use_default;

    } # End of DEFAULT loop

    # DEFAULT:
    # next DEFAULT goes here
    #
    # OK, this is the second half of the CHAR loop, which is only reached
    # if the if chain above reaches else{} or next DEFAULT is used.

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

        # make sure the char is acceptable
        if (defined $catch->{valid_chars} && $char !~ $catch->{valid_chars}) {
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

    # the current character is \, so set $c->{escaped} for the next
    # character. unless, of course, this escape itself is escaped.
    # (determined with current{escaped})
    if ($char eq '\\' && !$c->is_escaped) {
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

    # this is a block. parse it
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

1
