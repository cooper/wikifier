# Copyright (c) 2014, Mitchell Cooper
#
# Wikifier::Parser is a function class of Wikifier which parses a wiki file.
# The parser separates the file into block types and then passes those to
# Wikifier::BlockManager for block class loading and object creation.
#
# This class is never to be used on its own. You must use Wikifier::Wiki for a high-level
# Wiki manager or the medium-level Wikifier::Page for managing a single page.
#
package Wikifier::Parser;

use warnings;
use strict;
use 5.010;

use Scalar::Util qw(blessed);
use Wikifier::Utilities qw(trim L);

###############
### PARSING ###
###############

# parse a wiki file.
sub parse {
    my ($wikifier, $page, $file) = @_;
    $file = $page->path if $page;

    # no file given.
    if (!defined $file) {
        return "No file specified for parsing";
    }

    # open the file.
    my $fh;
    if (!open $fh, '<', $file) {
        return "Couldn't open '$file': $!";
    }

    # set initial parse info.
    my $current = {
        block => $wikifier->{main_block},
        last  => {}
    };

    # read it line-by-line.
    while (my $line = <$fh>) {
        $line =~ s/[\r\n\0]//g;     # remove returns and newlines.
        $line = trim($line);        # remove prefixing and suffixing whitespace.
        $current->{line} = $.;
        my ($i, $err) = $wikifier->handle_line($line, $page, $current);
        return "Line $.:$i: $err" if $err;
    }

    # some block was not closed.
    if ($current->{block} != $page->{main_block}) {
        my ($type, $line, $col) = @{ $current->{block} }{ qw(type line col) };
        return "Line $line:$col: $type\{} still open at EOF";
    }

    # run ->parse on children.
    $page->{main_block}->parse($page);

    return;
}

# parse a single line.
sub handle_line {
    my ($wikifier, $line, $page, $current) = @_;

    # illegal regex filters out variable declaration.
    if ($line =~ m/^\s*\@([\w\.]+):\s*(.+);\s*$/) {
        $page->set($1, $wikifier->parse_formatted_text($page, $2));
        return;
    }

    # variable boolean.
    elsif ($line =~ m/^\s*\@([\w\.]+);\s*$/) {
        $page->set($1, 1);
        return;
    }

    # only parsing variables.
    return if $page->{vars_only};

    # pass on to main parser.
    my $i = 0;
    my @chars = split(//, $line), "\n";
    for (0..$#chars) {
        $current->{col} = ++$i;
        $current->{next_char} = $chars[$i + 1] // '';
        my $err = $wikifier->handle_character($_, $page, $current);
        return ($i, $err) if $err;
    }

    return;
}

# % current
#   char:       the current character.
#   word:       the current word. (may not yet be complete.)
#   escaped:    true if the current character was escaped. (last character = \)
#   block:      the current block object.
#   ignored:    true if the character is a master parser character({, }, etc.).
#   line:       current line number
#   col:        current column number (actually column + 1)
#
# %last
#   char:       the last parsed character.
#   word:       the last full word.
#   escaped:    true if the last character was escaped. (2nd last character = \)
#   block:      the current block object's parent block object.


# parse a single character.
# note: never return from this method; instead last from for loop.
sub handle_character {
    my ($wikifier, $char, $page, $current) = @_;
    my $last = $current->{last};

    # set current character.
    $current->{char} = $char;

    for ($char) {

    # comment entrance and closure.
    if ($char eq '/' && $current->{next_char} eq '*') {
        $current->{in_comment} = 1;
        last;
    }
    if ($char eq '*' && $current->{next_char} eq '/') {
        delete $current->{in_comment};
        last;
    }

    # inside a comment.
    last if $current->{in_comment};

    # space. terminates a word.
    # delete the current word, setting its value to the last word.
    when (' ') {

        # that is, unless the current word a space.
        # note: I can't remember why I felt the need for this code.
        if (!(defined $current->{word} && $current->{word} eq ' ')) {
            $last->{word} = delete $current->{word};
            continue;
        }
    }

    # left bracket indicates the start of a block.
    when ('{') {
        $current->{ignored} = 1;
        continue if $current->{escaped}; # this character was escaped; continue.

        # now we must remove the new block type from the
        # current block's last content element.

        # set some initial variables for the loop.
        my $content       = $current->{block}{content}[-1];
        my $block_type    = my $block_name    = '';
        my $in_block_name = my $chars_scanned = 0;

        return "Block has no type"
            if !length $content;

        # chop one character at a time from the end of the content.
        while (my $last_char = chop $content) { $chars_scanned++;

            # entering block name.
            if ($last_char eq ']') {
                next if !$in_block_name++;
                # if it was at 0, we just entered the block name.
            }

            # exiting block name.
            elsif ($last_char eq '[') {
                next if !--$in_block_name;
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
                next;
            }

            # this could be a space between things.
            elsif ($last_char =~ m/\s/ && !length $block_type) {
                next;
            }

            # I give up. bail!
            else {
                $chars_scanned--; # we do not possess this character.
                last;
            }

        }

        #
        # remove the block type and name from the current block's content.
        #
        # note: it is very likely that a single space will remain, but this will later
        # be trimmed out by a further cleanup.
        #
        $current->{block}{content}[-1] =
            substr($current->{block}{content}[-1], 0, -$chars_scanned);

        # if the block type contains dot(s), it has classes.
        my @block_classes;
        if (index($block_type, '.') != -1) {
            my @split      = split /\./, $block_type;
            $block_type    = shift @split;
            @block_classes = @split;
        }

        # if the block type starts with $, it's a model.
        my $first = \substr($block_type, 0, 1);
        if ($$first eq '$') {
            $$first = '';
            $block_name = $block_type;
            $block_type = 'model';
        }

        # create the new block.
        $current->{block} = $wikifier->create_block(
            line    => $current->{line},
            col     => $current->{col},
            parent  => $current->{block},
            type    => $block_type,
            name    => $block_name,
            classes => \@block_classes
        );

    }

    # right bracket indicates the closing of a block.
    when ('}') {
        $current->{ignored} = 1;
        continue if $current->{escaped}; # this character was escaped; continue;

        # we cannot close the main block.
        if ($current->{block} == $page->{main_block}) {
            L "Attempted to close main block";
            return;
        }

        # this is an if statement.
        my @add_contents;
        if ($current->{block}{type} eq 'if') {
            my $conditional = $current->{block}{name};

            # variable.
            if ($conditional =~ /^@([\w.]+)$/) {
                $conditional = $page->get($1);
            }

            # add everything from within the if block IF conditional is true.
            @add_contents = @{ $current->{block}{content} } if $conditional;
            $current->{conditional} = !!$conditional;

        }

        # this is an else statement.
        elsif ($current->{block}{type} eq 'else') {

            # the conditional was false. add the contents of the else.
            @add_contents = @{ $current->{block}{content} }
                unless $current->{conditional};

        }

        # normal block. add the block itself.
        else {
            @add_contents = $current->{block};
        }

        # close the block, returning to its parent.
        $current->{block}{closed} = 1;
        push @{ $current->{block}{parent}{content} }, @add_contents;
        $current->{block} = $current->{block}{parent};

    }

    # ignore backslashes - they are handled later below.
    when ('\\') {
        # this character should NEVER be ignored.
        # if it's escaped, continue to default.
        continue if $current->{escaped};
    }

    # any other character.
    default {

        # at this point, anything that needs escaping should have been handled by now.
        # so, if this character is escaped and reached all the way to here, we will
        # pretend it's not escaped by reinjecting a backslash. this allows further parsers
        # to handle escapes (in particular, the formatting parser.)
        my $append = $char;
        if (!$current->{ignored} && $current->{escaped}) {
            $append = "$$last{char}$char";
        }

        # if it's not a space or newline, append to current word.
        if ($char ne ' ' && $char ne "\n") {
            $current->{word}  = '' if !defined $current->{word};
            $current->{word} .= $append;
        }

        # append character to current block's content.

        # if the current block's content array is empty, push the character.
        if (!scalar @{ $current->{block}{content} }) {
            push @{ $current->{block}{content} }, $append;
        }

        # array is not empty.
        else {

            # if last element of the block's content is blessed, it's a child block.
            my $last_value = $current->{block}{content}[-1];
            if (blessed($last_value)) {

                # push the character to the content array, creating a new string element.
                push @{ $current->{block}{content} }, $append;

            }

            # not blessed, so simply append the character to the string.
            else {
                $current->{block}{content}[-1] .= $append;
            }

        }


    } # end of default

    } # end of switch

    # set last stuff for next character.
    $last->{char}       = $char;
    $last->{escaped}    = $current->{escaped};
    $current->{ignored} = 0;

    # the current character is \, so set $current->{escaped} for the next character.
    # unless, of course, this escape itself is escaped. (determined with current{escaped})
    if ($char eq '\\' && !$current->{escaped}) {
        $current->{escaped} = 1;
    }

    # otherwise, set current{escaped} to 0.
    else {
        $current->{escaped} = 0;
    }

    ### do not do anything below that depends on $current->{escaped} ###
    ###   because it has already been modified for the next char   ###

    return;
}

1
