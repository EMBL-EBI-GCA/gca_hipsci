#!/usr/bin/env perl

use strict;
use warnings;

use Net::OpenSSH;
use LWP::UserAgent;
use JSON;
use List::Util qw();
use Getopt::Long;

my $ssh_password;
my $ssh_user = 'is6';
my $ssh_host = 'ssh.sanger.ac.uk';
my $ssh_config_file = '/homes/streeter/.ssh/config';
my $ssh_known_hosts_file = '/homes/streeter/.ssh/known_hosts';
GetOptions('ssh_user=s' => \$ssh_user,
          'ssh_host=s' => \$ssh_host,
          'ssh_password=s' => \$ssh_password,
          'ssh_config_file=s' => \$ssh_config_file,
          'ssh_known_hosts_file=s' => \$ssh_known_hosts_file,
          );

my $ssh = Net::OpenSSH->new($ssh_host, user => $ssh_user, password=>$ssh_password,
    master_opts => [-F => $ssh_config_file, -o => "UserKnownHostsFile $ssh_known_hosts_file"],
);

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
