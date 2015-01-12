#!/usr/bin/env perl

use strict;
use warnings;

use Net::OpenSSH;
use LWP::UserAgent;
use JSON;
use List::Util;
use Getopt::Long;

my $ssh_password;
my $ssh_user = 'is6';
my $ssh_host = 'ssh.sanger.ac.uk';
GetOptions('ssh_user=s' => \$ssh_user,
          'ssh_host=s' => \$ssh_host,
          'ssh_password=s' => \$ssh_password,
          );

my $ssh = Net::OpenSSH->new($ssh_host, user => $ssh_user, password=>$ssh_password);

my $ua = LWP::UserAgent->new(ssl_opts => {verify_hostname => 0});
$ua->default_header('Content-Type' => 'application/json');
my $json = JSON->new->allow_nonref;

my $response = $ua->post('https://localhost:9090/rest/qc/nodes_of_label',
    Content => $json->encode({label => 'Group'}),
  );
my $groups = $json->decode($response->content);
my $hipsci_group_id = (List::Util::first {$_->{properties}->{name} eq 'hipsci'} @$groups)->{id};

$response = $ua->post('https://localhost:9090/rest/qc/nodes_of_label',
    Content => $json->encode({label => 'Study', groups => $hipsci_group_id}),
  );
my $studies = $json->decode($response->content);
my @study_ids = map {$_->{id}} @$studies;

$response = $ua->post('https://localhost:9090/rest/qc/nodes_of_label',
    Content => $json->encode({label => 'Donor', studies => join(',', @study_ids)}),
  );
my $donors = $json->decode($response->content);

DONOR:
foreach my $donor_id (map {$_->{id}} @$donors) {
  $donor_id = 8062;
  $donor_id += 0; # forces it to be treated as a number in the json encoding
  $response = $ua->post('https://localhost:9090/rest/qc/donor_qc',
      Content => $json->encode({donor => $donor_id}),
    );
  my $donor_qc = $json->decode($response->content);
  use Data::Dumper; print Dumper $donor_qc;
  last DONOR;
}
