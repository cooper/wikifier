package Wikifier::nginx;

use warnings;
use strict;

use nginx;

# global wiki variables.
my %wiki_variables = (
    stats => {
        library => {
            books => '151,785,778'
        }
    }
);

require Wikifier::Wiki;

our $wiki = Wikifier::Wiki->new();

sub handler {
    my $r      = shift;
    my $length = 0;
    
    $r->uri =~ m|/(.+?)$|;
    my $page_name = $1;
    my $result    = $wiki->display($page_name);

    if ($result->{type} eq 'not found') {
        return &HTTP_NOT_FOUND;
    }
    
    $length = $result->{length};
    
    # if we have an etag and the client sent an etag, check if they're the same.
    if (defined $result->{etag} && defined(my $etag_in = $r->header_in('If-None-Match'))) {
    
        # they're equal.
        if ($etag_in eq $result->{etag}) {
            return &HTTP_NOT_MODIFIED;
        }
        
    }
    
    # if we have a last modified date and the client sent one, check if they're the same.
    if (defined $result->{modified} &&
        defined(my $mod_in = $r->header_in('If-Modified-Since'))) {
        
        # they're equal.
        if ($mod_in eq $result->{modified}) {
            return &HTTP_NOT_MODIFIED;
        }
        
    }
        
    # if this is a page, inject the header and footer.
    if ($result->{type} eq 'page') {
        
#        # header.          FIXME
#        if ($options{header}) {
#            my $html = Wikifier::Wiki::file_contents($options{header});
#            $html    = _replace_variables($result, $html);
#            $result->{content} = $html.$result->{content};
#            $length = length $result->{content};
#        }
#        
#        # footer.
#        if ($options{footer}) {
#            my $html = Wikifier::Wiki::file_contents($options{footer});
#            $html    = _replace_variables($result, $html);
#            $result->{content} = $result->{content}.$html;
#            $length  = length $result->{content};
#        }
        
    }
    
    # send headers.
    
    $r->header_out('Last-Modified',  $result->{modified});
    $r->header_out('Etag',           $result->{etag}    )   if defined $result->{etag};
    $r->header_out('Content-Length', $length            );
    $r->header_out('X-Powered-By',   'https://github.com/cooper/wikifier');
    $r->send_http_header($result->{mime});
    return &OK if $r->header_only;
    
    # send body.
    $r->print($result->{content});
    return &OK;
    
}

# VERY illegal regex replaces for template variables.
sub _replace_variables {
    my ($result, $html) = @_;
    
    $html =~ s/\{\$page\.title\}/$$result{title}/g;
    $html =~ s/\{\$page\.file\}/$$result{file}/g;
    
    return $html;
}

1;
__END__
