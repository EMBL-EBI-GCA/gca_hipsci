#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);
use ReseqTrack::Tools::ERAUtils qw(get_erapro_conn);

my @era_params = ('ops$laura');
my $study_id;
&GetOptions(
    'password=s'              => \$era_params[1],
    'era_dbname=s'              => \$era_params[2],
    'study_id=s' => \$study_id,
);
my $era_db = get_erapro_conn(@era_params);
my $sql = 'select distinct sam.biosample_id from sample sam, run_sample rs, run r, experiment e, study s where sam.sample_id=rs.sample_id and r.run_id=rs.run_id and r.experiment_id=e.experiment_id and e.study_id=s.study_id and s.ega_id=?';
my $sth = $era_db->dbc->prepare($sql) or die "could not prepare $sql";

my %allowed_ids;
my ($ips_lines, $tissues) = @{read_cgap_report()}{qw(ips_lines tissues)};
SAMPLE:
foreach my $sample (@$ips_lines, @$tissues) {
  next SAMPLE if ! $sample->biosample_id;
  $allowed_ids{$sample->biosample_id} = 1;
}

$sth->bind_param(1, $study_id);
$sth->execute or die "could not execute";
foreach my $row (@{$sth->fetchall_arrayref()}) {
  my $ega_biosample_id = $row->[0];
  if (! $allowed_ids{$ega_biosample_id}) {
    printf "Invalid Biosample ID %s for study %s\n", $ega_biosample_id, $study_id;
  }
}
