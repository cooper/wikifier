package Wikifier::nginx;

use warnings;
use strict;

use nginx;
use Wikifier;

my %options = (
    file => shift @ARGV,
    wiki => {
        name            => 'NoTrollPlzNet Library',
        wiki_root       => '',
        image_directory => '/home/www/main/paranoia/files',
        image_address   => 'http://images.notroll.net/paranoia/files',
        variables       => \%wiki_variables,
        size_images     => 'server',
        image_sizer     => \&image_sizer,
        external_root   => 'http://en.wikipedia.org/wiki',
        rounding        => 'up'
    }
);

# global wiki variables.
my %wiki_variables = (
    stats => {
        library => {
            books => '151,785,778'
        }
    }
);

sub handler {
    my $r = shift;
    
    # create the page object.
    my $page = Wikifier::Page->new(%options);

    # parse the page.
    $page->parse();

    # print the generated HTML.
    $r->print($page->html());
    $r->rflush;
    
    # success.
    return OK;
}
 
 

# image sizer.
sub image_sizer {
    my %opts = @_;
    my ($file, $width, $height) = ($opts{file}, $opts{width}, $opts{height});
    
    # notroll.net image sizer takes no 'auto' argument; just leave them out.
    $width  = $width  eq 'auto' ? '' : $width;
    $height = $height eq 'auto' ? '' : $height;
    
    # return the full URL of the image.
    return "http://images.notroll.net/paranoia/files/$file?height=$height&amp;width=$width";
}

1;
__END__
