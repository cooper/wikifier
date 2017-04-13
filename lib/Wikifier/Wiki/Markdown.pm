# Copyright (c) 2017, Mitchell Cooper
package Wikifier::Wiki;

use warnings;
use strict;
use 5.010;

use Wikifier::Utilities qw(L Lindent back align);
use CommonMark qw(:node :event :list);
use Cwd qw(abs_path);

# all markdown files
sub all_markdowns {
    my $wiki = shift;
    my $dir = $wiki->opt('dir.md');
    return if !length $dir;
    return unique_files_in_dir($dir, 'md');
}

sub convert_markdown {
    my ($wiki, $md_name) = (shift, @_);
    Lindent "($md_name)";
    my $result = $wiki->_convert_markdown(@_);
    L align('Error', $result->{error}) if $result->{error};
    back;
    return $result;
}

sub _convert_markdown {
    my ($wiki, $md_name, %opts) = @_;
    my $md_path   = abs_path($wiki->opt('dir.md')."/$md_name");
    my $page_path = $wiki->path_for_page($md_name);
    
    # no such markdown file
    return display_error('Markdown file does not exist.')
        if !-f $md_path;
        
    # filename and path info
    my $result = {};
    $result->{file} = $md_name;         # with extension
    $result->{name} = (my $md_name_ne = $md_name) =~ s/\.md$//; # without
    $result->{path} = $page_path;       # absolute path
    
    # page content
    $result->{type} = 'markdown';
    $result->{mime} = 'text/plain'; # wikifier language
    
    # slurp the markdown file
    my $md_text = file_contents($md_path);
    
    # generate the wiki source
    my $source = $wiki->generate_from_markdown($md_text, %opts);
    $result->{content} = $source;
    
    # write to file
    open my $fh, '>', $page_path
        or return display_error('Unable to write page file.');
    print $fh $source;
    close $fh;
    
    return $result;
}

# NODE_NONE
# NODE_DOCUMENT
# NODE_BLOCK_QUOTE
# NODE_LIST
# NODE_ITEM
# NODE_CODE_BLOCK
# NODE_HTML
# NODE_PARAGRAPH
# NODE_HEADER
# NODE_HRULE
# NODE_TEXT
# NODE_SOFTBREAK
# NODE_LINEBREAK
# NODE_CODE
# NODE_INLINE_HTML
# NODE_EMPH
# NODE_STRONG
# NODE_LINK
# NODE_IMAGE
# NODE_CUSTOM_BLOCK
# NODE_CUSTOM_INLINE
# NODE_HTML_BLOCK
# NODE_HEADING
# NODE_THEMATIC_BREAK
# NODE_HTML_INLINE

my %es = (
    EVENT_ENTER , 'ENTER',
    EVENT_EXIT  , 'EXIT ',
    EVENT_DONE  , 'DONE '
);

sub generate_from_markdown {
    my ($wiki, $md_text, %opts) = @_;
    my $source = '';
    my $indent = 0;
    my $header_level = 0;
    
    my $add_text = sub {
        my ($text, $indent_change) = @_;
        $indent += $indent_change if $indent_change < 0;
        $source .= "\n".('    ' x $indent) if substr($source, -1) eq "\n";
        $source .= $text;
        $indent += $indent_change if $indent_change > 0;
    };
    
    # parse the markdown file
    my $doc = CommonMark->parse(string => $md_text);
    
    # iterate through nodes
    my $iter = $doc->iterator;
    while (my ($ev_type, $node) = $iter->next) {
        my $node_type = $node->get_type;
        my $node_type_s = $node->get_type_string;
        print "E $es{$ev_type} N $node_type_s\n";
        
        # heading
        if ($node_type == NODE_HEADING) {
            
            # entering the header
            if ($ev_type == EVENT_ENTER) {
                
                # if we already have a header of this level open, this
                # terminates it. if we have a header of a lower level (higher
                # number) open, this terminates it and all others up to the
                # biggest level.
                my $level = $node->get_header_level;
                if ($level <= $header_level) {
                    $add_text->("}\n", -1) for $level..$header_level;
                }
                $header_level = $level;
                
                $add_text->("section [");
            }
            
            # closing the header starts the section block
            else {
                $add_text->("] {\n", 1);
            }
        }
        
        # paragraph
        if ($node_type == NODE_PARAGRAPH) {
            if ($ev_type == EVENT_ENTER) {
                $add_text->("p {\n", 1);
            }
            else {
                $add_text->("}\n", -1);
            }
        }
        
        # plain text
        if ($node_type == NODE_TEXT) {
            $add_text->($node->get_literal);
        }
        
        # soft line break
        if ($node_type == NODE_SOFTBREAK) {
            $add_text->("\n");
        }
        
        # hard line break
        if ($node_type == NODE_LINEBREAK) {
            $add_text->("[nl]");
        }
    }
    
    # close remaining sections
    if ($header_level) {
        $add_text->("}\n", -1) for 1..$header_level;
    }
    
    return $source;
}

1
