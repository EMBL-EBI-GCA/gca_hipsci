
package ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils;

use strict;
use warnings;

use Text::Delimited;
use ReseqTrack::Tools::HipSci::CGaPReport::Donor;
use ReseqTrack::Tools::HipSci::CGaPReport::Tissue;
use ReseqTrack::Tools::HipSci::CGaPReport::IPSLine;
use DateTime::Format::ISO8601;

use Exporter 'import';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(read_cgap_report get_latest_file);
#use Exporter;
#use vars qw(@ISA @EXPORT);
#@ISA = qw(Exporter);
#@EXPORT = qw(read_cgap_report get_latest_file);

our $cgap_report_dir = '/nfs/research2/hipsci/drop/hip-drop/incoming/cgap_dnap_reports';
our $cgap_report_suffix = '.hipsci_progress.csv';


sub read_cgap_report {
  my (%args) = @_;
  my $file = $args{file}
      || get_latest_file(
              days_old => $args{days_old},
              date_iso => $args{date_iso},
          );
    
  my $sanger_file = new Text::Delimited;
  $sanger_file->delimiter(';');
  $sanger_file->open($file) or die "could not open $file $!";
  my (%donors, %tissues, %ips_lines);
  LINE:
  while (my $line_data = $sanger_file->read) {
    my ($donor_id, $tissue_id, $ips_id) = @{$line_data}
          {qw(dp_donor_cohort dp_cell_line_sample lp_cell_line_sample)};
    my $donor = $donors{$donor_id} if $donor_id;
    my $tissue = $tissues{$tissue_id} if $tissue_id;
    my $ips_line = $ips_lines{$ips_id} if $ips_id;

    if (!$donor) {
      $donor = ReseqTrack::Tools::HipSci::CGaPReport::Donor->new( %$line_data);
      next LINE if ! $donor->has_values;
      $donors{$donor_id} = $donor;
    }
    if (!$tissue) {
      $tissue = ReseqTrack::Tools::HipSci::CGaPReport::Tissue->new( %$line_data);
      next LINE if ! $tissue->has_values;
      $tissue->donor($donor);
      $tissues{$tissue_id} = $tissue;
      push(@{$donor->tissues}, $tissue);
    }
    if (!$ips_line) {
      $ips_line = ReseqTrack::Tools::HipSci::CGaPReport::IPSLine->new( %$line_data);
      next LINE if ! $ips_line->has_values;
      $ips_line->tissue($tissue);
      $ips_lines{$ips_id} = $ips_line;
      push(@{$tissue->ips_lines}, $ips_line);
    }

  }
  $sanger_file->close;

  return {donors => [values %donors], tissues => [values %tissues], ips_lines => [values %ips_lines], file => $file};
}

sub get_latest_file {
  my (%args) = @_;
  my $time = time();
  if (my $date_iso = $args{date_iso}) {
    $time = DateTime::Format::ISO8601->parse_datetime($date_iso)->epoch();
  }
  if (my $days_old = $args{days_old}) {
    $time -= 86400*$days_old;
  }
  my ($year, $month, $day) = (localtime($time))[5,4,3];
  my $date = sprintf("%04d%02d%02d", $year+1900, $month+1, $day);
  my $file = "$cgap_report_dir/$date$cgap_report_suffix";
  if (! -f $file) {
    ($year, $month, $day) = (localtime($time - 86400))[5,4,3];
    $date = sprintf("%04d%02d%02d", $year+1900, $month+1, $day);
    $file = "$cgap_report_dir/$date$cgap_report_suffix";
  }
  return $file;
  
}

1;
