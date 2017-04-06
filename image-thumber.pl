#!/usr/bin/perl
use strict;
use warnings;
use Imager;
use Template;
use Data::Printer;

use File::Basename qw(dirname basename);
use autodie;

my $template = Template->new;

my $image_dir = "images/source";

# https://metacpan.org/pod/Imager
# https://metacpan.org/pod/distribution/Imager/lib/Imager/Transformations.pod#scale()
my @image_files = (
    glob("$image_dir/*/*.jpg"),
    glob("$image_dir/*/*.png"),
);
    
my @label_files = glob("$image_dir/*/label.txt");
my %category_label_map;
my %image_rules_by_category;

foreach my $label_file (@label_files) {
    my $category = basename(dirname($label_file));
    
    open my $label_fh, '<', $label_file;
    $category_label_map{$category} = <$label_fh>;
    while (my $line = <$label_fh>) {
        my ($re, $label) = $line =~ m!^/(.+)/\s+(.+)$!;
        my %rule = (
            regex => $re,
            label => $label,
        );
        push @{ $image_rules_by_category{$category} }, \%rule;
    }
    close $label_fh;
}

my %images_by_category;

foreach my $image_file (@image_files) {
    # skip thumbnail images that we've generated.
    if ($image_file =~ /\bthumb-/) {
        unlink($image_file);
    }
}

foreach my $image_file (sort @image_files) {
    my $dir        = dirname($image_file);
    my $base       = basename($image_file);
    my $category   = basename($dir);
    my $thumb_file = "$dir/thumb-$base";

    next if $base =~ /^thumb/;

    my $img = Imager->new( file => $image_file )
        or die Imager->errstr();
    my $thumb = $img->scale(
        xpixels => 150,
        ypixels => 150,
        type => 'min',
    );
    my $image_label;
    if ($image_rules_by_category{$category}) {
        foreach my $rule (@{ $image_rules_by_category{$category} }) {
            if ($base =~ /$rule->{regex}/) {
                $image_label = $rule->{label};
            }
        }
    }
    
    
    $thumb->write( file => $thumb_file ) or
      die $thumb->errstr;
      
    my %info = (
        original_url => "/$image_file",
        thumb_url    => "/$thumb_file",
        label        => $image_label // $base,
    );
    push @{ $images_by_category{$category} }, \%info;
}

my %tt_vars = (
    images_by_category => \%images_by_category,
    category_label_map => \%category_label_map,
);

$template->process(
    "thumb-index.tt2", \%tt_vars, "thumb-index.html"
);

system("zip", "-r", "images.zip", "images");


