
use warnings;
use strict;
use JSON::MaybeXS;

# IDR data is saved in a json format in
use Data::Dumper;
use lib qw(..);
use JSON qw( );
my $filename = '/homes/hipdcc/IDR_data/IDR_json_data.json';
my $json_text = do {
   open(my $json_fh, "<:encoding(UTF-8)", $filename)
      or die("Can't open \$filename\": $!\n");
   local $/;
   <$json_fh>
};
my $json = JSON->new;
my $data = $json->decode($json_text);
print $data;
