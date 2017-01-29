# Copyright (c) 2014, Mitchell Cooper
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

use Scalar::Util qw(blessed);
use Wikifier::Utilities qw(trim L);

###############
### PARSING ###
###############

# parse a wiki file.
sub parse {
    my ($wikifier, $page, $file) = @_;

    # if a page is provided, use ->{source} or ->path
    if ($page) {
        $file = $page->path;
        $file = \$page->{source} if defined $page->{source};
    }

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
    my $current = bless {
        block       => $wikifier->{main_block},
        warnings    => []
    }, 'Wikifier::Parser::Current';

    # read it line-by-line.
    while (my $line = <$fh>) {
        $line =~ s/[\r\n\0]//g;     # remove returns and newlines.
        $line = trim($line);        # remove prefixing and suffixing whitespace.
        $current->{line} = $.;
        print "handle_line($line)\n";
        my ($i, $err) = $wikifier->handle_line($line, $page, $current);
        next unless $err;
        $err = "Line $.:$i: $err";
        close $fh;
        return $err;
    }

    close $fh;

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
    my ($wikifier, $line, $page, $c) = @_;

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
    my @chars = (split(//, $line), "\n");
    CHAR: for my $i (0 .. $#chars) {
        next CHAR if delete $c->{skip_next_char};
        $c->{col} = $i;
        $c->{next_char} = $chars[$i + 1] // '';
        print "handle_character($chars[$i])\n";
        my $err = $wikifier->handle_character($chars[$i], $page, $c);
        return ($i, $err) if $err;
    }

    return;
}

# %current
#   char:       the current character.
#   escaped:    true if the current character was escaped. (last character = \)
#   block:      the current block object.
#   ignored:    true if the character is a master parser character({, }, etc.).
#   line:       current line number
#   col:        current column number (actually column + 1)

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
        $c->mark_comment;
        next CHAR;
    }
    if ($char eq '*' && $c->{next_char} eq '/') {
        $c->clear_comment;
        $c->{skip_next_char}++;
        next CHAR;
    }

    # inside a comment.
    next CHAR if $c->is_comment;
    print "$char: not a comment\n";

    # left bracket indicates the start of a block.
    if ($char eq '{') {
        $c->mark_ignored;
        next DEFAULT if $c->is_escaped;
        print "$char: not escaped\n";

        # now we must remove the new block type from the
        # current block's last content element.

        # set some initial variables for the loop.
        my $content       = $c->last_content;
        my $block_type    = my $block_name    = '';
        my $in_block_name = my $chars_scanned = 0;

        return "Block has no type"
            if !length $content;

        # chop one character at a time from the end of the content.
        BACKCHAR: while (length(my $last_char = chop $content)) {
            $chars_scanned++;
            print "backchar: $last_char; $block_name\n";

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
        print "last_content: ", $c->last_content, " -> ";
        $c->last_content = substr($c->last_content, 0, -$chars_scanned);
        print $c->last_content, "\n";

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
        $c->block = my $block = $wikifier->create_block(
            line    => $c->{line},
            col     => $c->{col},
            parent  => $c->block,
            type    => $block_type,
            name    => $block_name,
            classes => \@block_classes
        );
        print "created block: ", $block->type, " (hopefully the same as ", $c->block->type, ")\n";
    }

    # right bracket indicates the closing of a block.
    elsif ($char eq '}') {
        $c->mark_ignored;
        next DEFAULT if $c->is_escaped;
        print "$char: not escaped\n";

        # we cannot close the main block.
        if ($c->block == $page->{main_block}) {
            return "Attempted to close main block";
        }

        # this is an if statement.
        my @add_contents;
        if ($c->block->type eq 'if') {
            my $conditional = $c->block->name;

            # variable.
            if ($conditional =~ /^@([\w.]+)$/) {
                $conditional = $page->get($1);
            }

            # add everything from within the if block IF conditional is true.
            @add_contents = $c->content if $conditional;
            $c->{conditional} = !!$conditional;
        }

        # this is an else statement.
        elsif ($c->block->type eq 'else') {

            # the conditional was false. add the contents of the else.
            @add_contents = $c->content unless $c->{conditional};
        }

        # normal block. add the block itself.
        else {
            @add_contents = $c->block;
        }

        # close the block
        $c->block->{closed}++;
        $c->block->{end_line}   = $c->{line};
        $c->block->{end_column} = $c->{column};

        # return to the parent
        $c->block = $c->block->parent;
        $c->push_content(@add_contents);
    }

    # ignore backslashes - they are handled later below.
    elsif ($char eq '\\') {
        next DEFAULT if $c->is_escaped;
        next CHAR;
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

    # append character to current block's content.

    # if the current block's content array is empty, push the character.
    if (!scalar $c->content) {
        $c->push_content($append);
    }

    # array is not empty. push or append it.
    else {

        # if last element of the block's content is blessed,
        # it's a child block.
        my $last_value = $c->last_content;
        if (blessed($last_value)) {

            # push the character to the content array,
            # creating a new string element.
            $c->push_content($append);
        }

        # not blessed, so simply append the character to the string.
        else { $c->append_content($append) }
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

package Wikifier::Parser::Current;

use warnings;
use strict;
use 5.010;

# escaped characters
sub is_escaped    {        shift->{escaped}   }
sub mark_escaped  {        shift->{escaped}++ }
sub clear_escaped { delete shift->{escaped}   }

# /* block comments */
sub is_comment    {        shift->{comment}   }
sub mark_comment  {        shift->{comment}++ }
sub clear_comment { delete shift->{comment}   }

# ignored characters
sub is_ignored    {        shift->{ignored}   }
sub mark_ignored  {        shift->{ignored}++ }
sub clear_ignored { delete shift->{ignored}   }

# the current block
sub block : lvalue {
    return shift->{block};
}

# return the content of the current block
sub content {
    my $c = shift;
    return @{ $c->{block}{content} };
}

# push content to the current block
sub push_content {
    my $c = shift;
    push @{ $c->{block}{content} }, @_;
}

# return the last element in the current block's content
sub last_content : lvalue {
    my $c = shift;
    return $c->{block}{content}[-1];
}

# append a string to the last element in the current block's content
sub append_content {
    my ($c, $append) = @_;
    $c->last_content .= $append;
}

1
