#!/usr/bin/env perl

use strict;
use warnings;

use LWP::UserAgent;
use JSON;
use List::Util qw();

my $ua = LWP::UserAgent->new(ssl_opts => {verify_hostname => 0});
$ua->default_header('Content-Type' => 'application/json');
my $json = JSON->new->allow_nonref;

my $response = $ua->post('https://localhost:9090/rest/qc/nodes_of_label',
    Content => $json->encode({label => 'Group'}),
  );
my $groups = $json->decode($response->content);
my $hipsci_group_id = (List::Util::first {$_->{properties}->{name} eq 'hipsci'} @$groups)->{id};

$hipsci_group_id+=0; # force it to be interpreted as a number
$response = $ua->post('https://localhost:9090/rest/qc/nodes_of_label',
    Content => $json->encode({label => 'Study', groups => $hipsci_group_id}),
  );
my $studies = $json->decode($response->content);
my %study_ids = map {($_->{id} => 1)} @$studies;

$response = $ua->post('https://localhost:9090/rest/qc/nodes_of_label',
    Content => $json->encode({label => 'Donor', studies => join(',', keys %study_ids)}),
  );
my $donors = $json->decode($response->content);
print map {$_->{id}, "\n"} @$donors;
