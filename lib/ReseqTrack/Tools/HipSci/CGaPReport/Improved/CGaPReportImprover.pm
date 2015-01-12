
package ReseqTrack::Tools::HipSci::CGaPReport::Improved::CGaPReportImprover;

use strict;
use warnings;

use Text::Delimited;
use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils;
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::Donor;
use ReseqTrack::Tools::HipSci::CGaPReport::Improved::IPSLine;
use List::Util qw();
use List::MoreUtils qw();
use BioSD;

use Exporter 'import';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(improve_donors improve_tissues improve_ips_lines);

my %disease_map = (bbs => 'bardet-biedl syndrome', 'nd' => 'neonatal diabetes', 'normal' => 'normal');

sub improve_donors {
  my (%args) = @_;
  my $donors = $args{donors};
  my $demographic_filename = $args{demographic_file};

  my %demographics_by_donor_id;
  my %demographics_by_friendly_name;
  if ($demographic_filename) {
    my $demographic_file = new Text::Delimited;
    $demographic_file->delimiter(";");
    $demographic_file->open($demographic_filename) or die "could not open $demographic_filename $!";
    LINE:
    while (my $line_data = $demographic_file->read) {
      if ($line_data->{'DonorID'}) {
        $demographics_by_donor_id{$line_data->{'DonorID'}} = $line_data;
      }
      if ($line_data->{'Friendly name'}) {
        $demographics_by_friendly_name{$line_data->{'Friendly name'}} = $line_data;
      }
    }
    $demographic_file->close;
  }

  foreach my $donor (@$donors) {
    bless $donor, 'ReseqTrack::Tools::HipSci::CGaPReport::Improved::Donor';
    my $donor_demographics;
    if (my $supplier_name = $donor->supplier_name) {
      $donor_demographics = $demographics_by_donor_id{$supplier_name};
    }
    if (!$donor_demographics && scalar @{$donor->tissues}) {
      my $tissue_name = $donor->tissues->[0]->name;
      my ($friendly_name) = $tissue_name =~ /-(\w{4})/;
      if ($friendly_name) {
        $donor_demographics = $demographics_by_friendly_name{$friendly_name};
      }
    }
    $donor_demographics //= {};

    # Fix gender
    my @genders = grep {$_ && $_ =~ /ale/} map {$_->gender} map {@{$_->sequencescape}} map {@{$_->ips_lines}} @{$donor->tissues};
    my $is_female = List::MoreUtils::any { /female/i } @genders;
    my $is_male = List::MoreUtils::any { ! /female/i } @genders;
    my $gender = ($is_male && $is_female) ? ''
              : $is_male ? 'male'
              : $is_female ? 'female'
              : undef;
    $gender //= $donor_demographics->{'Gender'} // '';
    $gender = lc($gender);
    $gender =~ s/[^\w]//g;
    $gender = $gender =~ /unknown/ ? '' : $gender;
    $donor->gender($gender);

    # Fix disease
    my $disease = $donor_demographics->{'Disease phenotype'};
    $disease = $disease ? ($disease_map{lc($disease)} // lc($disease)) : '';
    $donor->disease($disease);

    # Fix age
    my $age = $donor_demographics->{'Age-band'};
    $age = $age && $age !~ /unknown/i ? lc($age) : '';
    $donor->age($age);
    
    # Fix ethnicity
    my $ethnicity = $donor_demographics->{'Ethnicity'};
    $ethnicity = $ethnicity && $ethnicity !~ /unknown/i ? lc($ethnicity) : '';
    $donor->ethnicity($ethnicity);
  }
  return $donors;
}

sub improve_tissues {
  my(%args) = @_;
  my $tissues = $args{tissues};
  TISSUE:
  foreach my $tissue ( @$tissues) {
    if ($tissue->biosample_id) {
      my $tissue_biosample = BioSD::fetch_sample($tissue->biosample_id);
      if (!$tissue_biosample) {
        $tissue->biosample_id('');
        next TISSUE;
      }
      my $property = $tissue_biosample->property('cell type');
      $tissue->type($property ? $property->values->[0] : '');
    }
  }
  return $tissues;
}

sub improve_ips_lines {
  my(%args) = @_;
  my $ips_lines = $args{ips_lines};
  my $growing_conditions_filename = $args{growing_conditions_file};

  my %is_feeder_free;
  if ($growing_conditions_filename) {
    my $feeder_file = new Text::Delimited;
    $feeder_file->delimiter(";");
    $feeder_file->open($growing_conditions_filename) or die "could not open $growing_conditions_filename $!";
    LINE:
    while (my $line_data = $feeder_file->read) {
      next LINE if !$line_data->{sample} || !$line_data->{is_feeder_free};
      $is_feeder_free{$line_data->{sample}} = $line_data->{is_feeder_free};
    }
    $feeder_file->close;
  }

  IPS_LINE:
  foreach my $ips_line ( @$ips_lines) {
    bless $ips_line, 'ReseqTrack::Tools::HipSci::CGaPReport::Improved::IPSLine';

    # fix growing_conditions
    if ($ips_line->is_transferred) {
      $ips_line->growing_conditions('transferred');
    }
    elsif (my $is_feeder_free = $is_feeder_free{$ips_line->uuid}) {
      $is_feeder_free =~ s/\s+//g;
      $is_feeder_free = uc($is_feeder_free);
      $ips_line->growing_conditions($is_feeder_free eq 'Y' ? 'E8'
                                  : $is_feeder_free eq 'N' ? 'feeder'
                                  : '');
    }

    # fix name
    if ($ips_line->biosample_id) {
      my $ips_line_biosample = BioSD::fetch_sample($ips_line->biosample_id);
      if (!$ips_line_biosample) {
        $ips_line->biosample_id('');
        next IPS_LINE;
      }
      if ($ips_line->name !~ /HPSI/) {
        my @alternative_name_properties = grep {defined $_} ($ips_line_biosample->property('Sample Name'), $ips_line_biosample->property('synonym'));
        if (my $alternative_name = List::Util::first { /^HPSI/ } map {@{$_->values}} @alternative_name_properties) {
          $ips_line->name($alternative_name);
        }
      }
    }

  }
  return $ips_lines;
}

1;
