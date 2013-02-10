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

#############
# OPTIONS ###
#############

my %options = (
    page_dir     => '/home/www/source/about/pages',
    wikifier_dir => '/home/www/wikifier',
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

push @INC, (delete $options{wikifier_dir}).'/lib';
require Wikifier;

sub handler {
    my $r = shift;
    
    # create the page object.                # FIXME
    my $page = Wikifier::Page->new(%options, file => "$options{page_dir}/notrollplznet_library.page");

    # parse the page.
    $page->parse();

    # print the generated HTML.
    $r->print($page->html());
    $r->rflush;
    
    # success.
    #return OK();
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
