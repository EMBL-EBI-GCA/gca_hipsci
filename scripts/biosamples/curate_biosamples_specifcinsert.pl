#!/usr/bin/env perl

use strict;
use warnings;

use WWW::Mechanize;
use JSON -support_by_pp;
use Getopt::Long;
use JSON;
use Data::Dumper;

my ($dev, $authuser, $authpass, $currationfile);

GetOptions("dev" => \$dev,
           "authuser=s" => \$authuser,
           "authpass=s" => \$authpass,
           "currationfile=s" => \$currationfile,
);

die "missing authuser" if !$authuser;
die "missing authpass" if !$authpass;
die "missing curration file" if !$currationfile; #BiosampleID->field->value


my $authurl;

#Obtain AAI access token (if --dev then use dev authentication environment)
if ($dev){
  $authurl = 'https://explore.api.aap.tsi.ebi.ac.uk/auth'
}else{
  $authurl = 'https://api.aai.ebi.ac.uk/auth'
}
my $auth = WWW::Mechanize->new();
$auth->credentials( $authuser => $authpass);
$auth->get($authurl);
my $token = $auth->content();
$token = "Bearer ".$token;

open my $fh, '<', $currationfile or die "could not open $currationfile $!";
my @lines = <$fh>;
foreach my $line (@lines){
  chomp($line);
  my @parts = split("\t", $line);
  my $key = $parts[0];
  my $field = $parts[1];
  my $value = $parts[2];

  my $JSONpayload = '{
      "sample": "'.$key.'",
      "curation": {
        "attributesPre": [],
        "attributesPost": [
          {
            "type":"'.$field.'",
            "value":"'.$value.'"
          }
        ],
        "externalReferencesPre": [],
        "externalReferencesPost": []
      },
      "domain": "self.HipSci_DCC_curation"
      }';
  print $JSONpayload, "\n";
  my $currationbaseurl;
  if ($dev){
    $currationbaseurl = "https://wwwdev.ebi.ac.uk/biosamples/samples/"
  }else{
    $currationbaseurl = "https://www.ebi.ac.uk/biosamples/samples/"
  }
  my $currationurl = $currationbaseurl.$key."/curationlinks";
  print $currationurl, "\n\n";
  my $currate = WWW::Mechanize->new();    
  #$currate->show_progress(1);
  my $response = $currate->post($currationurl, 
  "Content" => $JSONpayload, 
  "accept" => "application/hal+json",
  "Content-Type" => "application/json",
  "Authorization" => $token
  );
  print $key, "\t", $field, "\t", $currate->status, "\n";
}