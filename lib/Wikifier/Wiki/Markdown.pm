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
    my $page_title;
    
    my $add_text = sub {
        my $text = shift;
        foreach my $line (split /(\n)/, $text, -1) {
            $source .= $line;
            $source .= ('    ' x $indent) if $line eq "\n";
        }
    };
    
    # parse the markdown file
    my $doc = CommonMark->parse(string => $md_text);
    
    # iterate through nodes
    my $iter = $doc->iterator;
    while (my ($ev_type, $node) = $iter->next) {
        my $node_type = $node->get_type;
        
        # NODE_TEXT
        # plain text
        if ($node_type == NODE_TEXT) {
            my $text = $node->get_literal;
            # FIXME: escape square brackets
            $page_title = $text if !length $page_title && $header_level;
            $add_text->($text);
        }
        
        # NODE_HEADING
        # heading
        elsif ($node_type == NODE_HEADING) {
            
            # entering the header
            if ($ev_type == EVENT_ENTER) {
                
                # if we already have a header of this level open, this
                # terminates it. if we have a header of a lower level (higher
                # number) open, this terminates it and all others up to the
                # biggest level.
                my $level = $node->get_header_level;
                if ($level <= $header_level) {
                    $indent--, $add_text->("\n}\n") for $level..$header_level;
                }
                $header_level = $level;
                
                $add_text->("sec [");
            }
            
            # closing the header starts the section block
            else {
                $indent++;
                $add_text->("] {\n");
            }
        }
        
        # NODE_PARAGRAPH
        # paragraph
        elsif ($node_type == NODE_PARAGRAPH) {
            if ($ev_type == EVENT_ENTER) {
                $indent++;
                $add_text->("p {\n");
            }
            else {
                $indent--;
                $add_text->("\n}\n");
            }
        }
        
        # NODE_SOFTBREAK
        # soft line break
        elsif ($node_type == NODE_SOFTBREAK) {
            $add_text->("\n");
        }
        
        # NODE_LINEBREAK
        # hard line break
        elsif ($node_type == NODE_LINEBREAK) {
            $add_text->("[nl]");
        }
        
        # NODE_LIST
        elsif ($node_type == NODE_LIST) {
            if ($ev_type == EVENT_ENTER) {
                # TODO: respect list type $node->get_list_type
                $indent++;
                $add_text->("list {\n");
            }
            else {
                $indent--;
                $add_text->("\n}\n");
            }
        }
        
        # NODE_ITEM
        elsif ($node_type == NODE_ITEM) {
            if ($ev_type == EVENT_EXIT) {
                $add_text->(";\n");
            }
        }
    
        # NODE_EMPH
        elsif ($node_type == NODE_EMPH) {
            if ($ev_type == EVENT_ENTER) {
                $add_text->('[i]');
            }
            else {
                $add_text->('[/i]');
            }
        }
        
        # NODE_STRONG
        elsif ($node_type == NODE_STRONG) {
            if ($ev_type == EVENT_ENTER) {
                $add_text->('[b]');
            }
            else {
                $add_text->('[/b]');
            }
        }
        
        # NODE_LINK
        elsif ($node_type == NODE_LINK) {
            if ($ev_type == EVENT_ENTER) {
                $add_text->('[')
            }
            else {
                my $url = $node->get_url;
                $add_text->("]($url)");
            }
        }
        
        # NODE_IMAGE
        elsif ($node_type == NODE_IMAGE) {
            # TODO
        }
        
        # NODE_CODE
        elsif ($node_type == NODE_CODE) {
            # FIXME
            my $code = $node->get_literal;
            $add_text->("[c]$code\[/c]");
        }
        
        # NODE_CODE_BLOCK
        elsif ($node_type == NODE_CODE_BLOCK) {
            my $code = $node->get_literal;
            my $old_indent = $indent;
            $indent = 0;
            $add_text->("code{{\n$code\n}}\n");
            $indent = $old_indent;
        }
        
        # do nothing
        elsif ($node_type == NODE_DOCUMENT) {
            
        }
        
        else {
            my $node_type_s = $node->get_type_string;
            L "Unknown markdown node '$node_type_s' ($es{$ev_type})";
        }
        
        # TODO:
        # NODE_NONE
        # NODE_DOCUMENT
        # NODE_BLOCK_QUOTE
        # NODE_HTML
        # NODE_HEADER
        # NODE_HRULE
        # NODE_INLINE_HTML
        # NODE_CUSTOM_BLOCK
        # NODE_CUSTOM_INLINE
        # NODE_HTML_BLOCK
        # NODE_THEMATIC_BREAK
        # NODE_HTML_INLINE
    }
    
    # close remaining sections
    if ($header_level) {
        $indent--, $add_text->("\n}\n") for 1..$header_level;
    }
    
    # page metadata
    
    my @meta = (
        'page.title'        => $page_title,
        'page.author'       => 'Markdown',
        'page.generated'    => \1
    );
    
    my $meta_source = '';
    while (my ($k, $v) = splice @meta, 0, 2) {
        next if ref $v && !$$v;
        next if !length $v;
        $meta_source .= "\@$k";
        $meta_source .= ": $v" if !ref $v;
        $meta_source .= ";\n";
    }
    
    return "$meta_source\n$source";
}

1
