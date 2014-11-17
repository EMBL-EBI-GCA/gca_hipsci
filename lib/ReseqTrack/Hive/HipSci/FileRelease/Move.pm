
package ReseqTrack::Hive::HipSci::FileRelease::Move;

use strict;
use File::Basename qw(fileparse dirname);
use ReseqTrack::Tools::Exception qw(throw);

use base ('ReseqTrack::Hive::Process::FileRelease::Move');

sub param_defaults {
  my ($self) = @_;
  return {
    %{$self->SUPER::param_defaults()},
    'derive_path_options' => {
        'free_base_dir' => '/nfs/research2/hipsci/drop/hip-drop/tracked/',
        'controlled_base_dir' => '/nfs/research2/hipsci/controlled/',
        'trim_dir' => '/nfs/research2/hipsci/drop/hip-drop/incoming',
    },
  };
}

sub derive_path {
  my ($self, $dropbox_path, $file_object) = @_;

  my $derive_path_options = $self->param('derive_path_options');
  my $controlled_base_dir = $derive_path_options->{controlled_base_dir};
  my $free_base_dir = $derive_path_options->{free_base_dir};
  throw("this module needs a controlled_base_dir") if ! defined $controlled_base_dir;
  throw("this module needs a free_base_dir") if ! defined $free_base_dir;

  my ($filename, $incoming_dirname) = fileparse($dropbox_path);

  my $destination;
  my $destination_base_dir = $free_base_dir;
  #my $destination_base_dir = $controlled_base_dir;

  if ($incoming_dirname =~ m{/incoming/keane}) {
    if ($filename =~ /\.vcf(\.gz)?$/) {
      $destination = $self->derive_keane_vcf(filename => $filename, destination_base_dir => $destination_base_dir);
    }
    elsif ($filename =~ /\.bam$/) {
      $destination = $self->derive_keane_bam(filename => $filename, destination_base_dir => $destination_base_dir);
    }
    elsif ($filename =~ /\.gtc$/) {
      $destination = $self->derive_keane_gtc(filename => $filename, destination_base_dir => $destination_base_dir);
    }
    elsif ($filename =~ /\.idat$/) {
      $destination = $self->derive_keane_idat(filename => $filename, destination_base_dir => $destination_base_dir);
    }
    elsif ($filename =~ /\.(txt)|(csv)$/) {
      $destination = $self->derive_keane_txt(filename => $filename, destination_base_dir => $destination_base_dir);
    }
    throw("cannot derive path for $filename") if !$destination;
  }
  elsif ($incoming_dirname =~ m{/incoming/lamond} ){
    if ($filename =~ /\.raw$/) {
      $destination = $self->derive_lamond_raw_file(filename => $filename, destination_base_dir => $destination_base_dir);
    }
    if ($filename =~ /\.txt$/ || $filename =~ /\.pdf$/) {
      $destination = $self->derive_lamond_processed_file(filename => $filename, destination_base_dir => $destination_base_dir);
    }
  }
  elsif ($incoming_dirname =~ m{/incoming/watt} ){
    if ($filename =~ /\.txt$/) {
      $destination = $self->derive_watt_txt_file(filename => $filename, destination_base_dir => $destination_base_dir);
    }
  }
  else {
    my $dirname = $incoming_dirname;
    if (my $trim = $derive_path_options->{trim_dir}) {
      $dirname =~ s/^$trim// or throw("could not trim $dirname $trim");
    }
    $destination = "$destination_base_dir/analysis/$dirname/$filename";
  }

  $destination =~ s/\/\/+/\//g;

  #throw(join("\t", $dropbox_path, $destination));
  return $destination;
}

# Use BioSD API to decide if sample is managed access
sub derive_is_controlled {
  my ($self, $donor) = @_;
  return 1;
}

# Use BioSD API when BioSamples records are accurate
sub derive_donor {
  my ($self, $cell_line_name) = @_;
  my ($donor_name) = $cell_line_name =~ /-([a-z]{4})(_\d+)?$/;
  throw("did not recognise donor name $cell_line_name") if !$donor_name;
  return $donor_name;
}

sub derive_date {
  my ($self, $filename) = @_;
  my ($date) = grep { /^\d{8}$/ } reverse split(/\./, $filename);
  return $date;
}

sub derive_keane_vcf {
  my ($self, %options) = @_;
  my $filename = $options{filename} or throw("missing filename");
  my $destination_base_dir = $options{destination_base_dir} or throw("missing destination_base_dir");
  #my $assay = (split(/\./, $filename))[2] or throw("did not get assay for $filename");
  my $date = $self->derive_date($filename) or throw("could not derive date $filename");
  my ($num_samples) = $filename =~ /\.(\d+)_?samples/i;
  my $group_name = $date;
  $group_name .= "_${num_samples}samples" if $num_samples;
  if ($filename =~ /\.HumanCoreExome.*\.imputed/) {
    $filename =~ s/(hipsci.wec).(HumanCoreExome)/$1.gtarray.$2/;
    return "$destination_base_dir/gtarray/imputed_vcf/$group_name/$filename";
  }
  elsif ($filename =~ /\.HumanCoreExome/) {
    $filename =~ s/(hipsci.wec).(HumanCoreExome)/$1.gtarray.$2/;
    return "$destination_base_dir/gtarray/vcf/$group_name/$filename";
  }
  elsif ($filename =~ /\.SureSelect_HumanAllExon[^\.]*\.mpileup/) {
    $filename =~ s/(hipsci.wes).(SureSelect)/$1.exomeseq.$2/;
    return "$destination_base_dir/exomeseq/vcf/$group_name/$filename";
  }
  elsif ($filename =~ /\.SureSelect_HumanAllExon[^\.]*\.imputed/) {
    $filename =~ s/(hipsci.[^.]+).(SureSelect)/$1.exomeseq.$2/;
    return "$destination_base_dir/exomeseq/imputed_vcf/$group_name/$filename";
  }
  else {
    return undef;
  }
}

#sub derive_keane_bai {
#  my ($self, %options) = @_;
#  my $filename = $options{filename} or throw("missing filename");
#  my $destination_base_dir = $options{destination_base_dir} or throw("missing destination_base_dir");
#  $filename =~ s/\.bai$//;
#  my $destination = $self->derive_keane_vcf(%options, filename => $filename);
#  return undef if !$destination;
#  if ( ! -e $destination) {
#    $self->reject_message('no bam file for index file');
#  }
#  return "$destination.bai";
#}

#sub derive_keane_tbi {
#  my ($self, %options) = @_;
#  my $filename = $options{filename} or throw("missing filename");
#  my $destination_base_dir = $options{destination_base_dir} or throw("missing destination_base_dir");
#  $filename =~ s/\.tbi$//;
#  my $destination = $self->derive_keane_vcf(%options, filename => $filename);
#  return undef if !$destination;
#  if ( ! -e $destination) {
#    $self->reject_message('no vcf file for index file');
#  }
#  return "$destination.tbi";
#}
#
sub derive_keane_bam {
  my ($self, %options) = @_;
  my $filename = $options{filename} or throw("missing filename");
  my $destination_base_dir = $options{destination_base_dir} or throw("missing destination_base_dir");
  my ($cell_line_name) = $filename =~ /^([^.]+)\./;
  throw("did not recognise cell line name $filename") if !$cell_line_name;
  my $donor_name = $self->derive_donor($cell_line_name);
  my $date = $self->derive_date($filename) or throw("could not derive date $filename");
  if ($filename =~ /\.exomeseq\.$date/) {
    return "$destination_base_dir/exomeseq/alignment/$donor_name/$cell_line_name/$filename";
  }
  if ($filename =~ /\.rnaseq\.$date/) {
    return "$destination_base_dir/rnaseq/alignment/$donor_name/$cell_line_name/$filename";
  }
  else {
    return undef;
  }
}

sub derive_keane_idat {
  my ($self, %options) = @_;
  my $filename = $options{filename} or throw("missing filename");
  my $destination_base_dir = $options{destination_base_dir} or throw("missing destination_base_dir");
  my ($cell_line_name) = $filename =~ /^([^.]+)\./;
  throw("did not recognise cell line name $filename") if !$cell_line_name;
  my $donor_name = $self->derive_donor($cell_line_name);
  my $date = $self->derive_date($filename) or throw("could not derive date $filename");
  if ($filename =~ /\.gexarray\.$date/) {
    return "$destination_base_dir/gexarray/primary_data/$donor_name/$cell_line_name/$filename";
  }
  if ($filename =~ /\.mtarray\.$date/) {
    return "$destination_base_dir/mtarray/primary_data/$donor_name/$cell_line_name/$filename";
  }
  else {
    return undef;
  }
}

sub derive_keane_gtc {
  my ($self, %options) = @_;
  my $filename = $options{filename} or throw("missing filename");
  my $destination_base_dir = $options{destination_base_dir} or throw("missing destination_base_dir");
  my ($cell_line_name) = $filename =~ /^([^.]+)\./;
  throw("did not recognise cell line name $filename") if !$cell_line_name;
  my $donor_name = $self->derive_donor($cell_line_name);
  my $date = $self->derive_date($filename) or throw("could not derive date $filename");
  if ($filename =~ /\.gtarray\.$date/) {
    return "$destination_base_dir/gtarray/primary_data/$donor_name/$cell_line_name/$filename";
  }
  else {
    return undef;
  }
}

sub derive_keane_txt {
  my ($self, %options) = @_;
  my $filename = $options{filename} or throw("missing filename");
  my $destination_base_dir = $options{destination_base_dir} or throw("missing destination_base_dir");
  my ($assay, $chip_name, $num_samples, $date, $filetype, $ext) = $filename =~ /hipsci\.(\w+)\.(\w+)\.(\d+)samples_(\d{8})(?:\.(\w+))?.(\w{3})$/;
  return undef if !$assay;
  if ($date) {
    my $group_name = "${date}_${num_samples}samples";
    my $parent_dir = $assay eq 'gexarray' ? 'genome_studio_files'
                  : $assay eq 'mtarray' ? 'txt_files'
                  : '';
    throw("error here") if !$parent_dir;
    if ($filetype) {
      $filetype = lc($filetype);
    }
    elsif ($assay eq 'gexarray') {
      $filetype = 'sample_map';
    }
    my $destination =  "$destination_base_dir/$assay/$parent_dir/$group_name/hipsci.$assay.$chip_name.${num_samples}samples.$date";
    if ($filetype) {
      $destination .= ".$filetype";
    }
    $destination .= ".$ext";
    return $destination;
  }
  elsif ($filename eq 'HumanMethylation450_15017482_v.1.1.csv') {
    return "$destination_base_dir/mtarray/txt_files/$filename";
  }
  else {
    return undef;
  }
}

#sub derive_lamond_raw_file {
#  my ($self, %options) = @_;
#  my $filename = $options{filename} or throw("missing filename");
#  my $destination_base_dir = $options{destination_base_dir} or throw("missing destination_base_dir");
#  my $file_details = $self->param('file');
#  my $cell_line_name = $file_details->{'cell_line'};
#  my $part_num = $file_details->{'part_num'};
#  my $replicate = $file_details->{'replicate'};
#  my $frac_method = $file_details->{'frac_method'};
#  throw("did not get cell_line_name") if !$cell_line_name;
#  throw("did not get part_num") if !$part_num;
#  throw("did not get replicate") if !$replicate;
#  throw("did not get frac_method") if !$frac_method;
#  $part_num = sprintf("%02d", $part_num);
#  $replicate .= '_hilic' if $frac_method eq 'hilic';
#  my $donor_name = $self->derive_donor($cell_line_name);
#  my $ctime = $file_details->{'dropbox'}->{'ctime'};
#  my ($year, $month, $day) = (localtime($ctime))[5,4,3];
#  my $date =  sprintf("%04d%02d%02d", $year+1900, $month+1, $day);
#  return "$destination_base_dir/proteomics/raw_data/$donor_name/$cell_line_name/$cell_line_name.proteomics.rep_$replicate.$date.f$part_num.raw";
#}
sub derive_lamond_raw_file {
  my ($self, %options) = @_;
  my $filename = $options{filename} or throw("missing filename");
  my $destination_base_dir = $options{destination_base_dir} or throw("missing destination_base_dir");
  my $file_details = $self->param('file');
  my $cell_line_name = $file_details->{'cell_line'};
  my $donor_name = $self->derive_donor($cell_line_name);
  return "$destination_base_dir/proteomics/raw_data/$donor_name/$cell_line_name/$filename";
}

sub derive_lamond_processed_file {
  my ($self, %options) = @_;
  my $filename = $options{filename} or throw("missing filename");
  my $destination_base_dir = $options{destination_base_dir} or throw("missing destination_base_dir");
  my ($cell_line_name, $rep, $type, $ext) = $filename =~ /^(HPSI\d{4}i-[a-z]{4}(?:_\d+)?)_proteomics_rep(\d)_([^\.]+)\.(\w+)/;
  throw("did not recognise string $filename") if !$ext;
  throw("unknown rep $rep") if $rep != 1 && $rep != 2;
  my $donor_name = $self->derive_donor($cell_line_name);
  my $analysis = $rep == 1 ? 'maxquant' : 'maxquant_ref';
  $type =~ s/\s+/_/g;

  my $file_details = $self->param('file');
  my $ctime = $file_details->{'dropbox'}->{'ctime'};
  my ($year, $month, $day) = (localtime($ctime))[5,4,3];
  my $date =  sprintf("%04d%02d%02d", $year+1900, $month+1, $day);

  return "$destination_base_dir/proteomics/maxquant/$donor_name/$cell_line_name/$cell_line_name.proteomics.$analysis.$date.$type.$ext";
}

#sub derive_index_file {
#  my ($self, %options) = @_;
#  my $filename = $options{filename} or throw("missing filename");
#  my $db_params = $self->param_required('reseqtrack_db');
#  my $db = ReseqTrack::DBSQL::DBAdaptor->new(%{$db_params});
#  my $fa = $db->get_FileAdaptor;
#  my $data_file_name = $filename;
#  $data_file_name =~ s/\.\w+$//g;
#  my $data_files = $fa->fetch_by_filename($data_file_name);
#  throw("did not data file corresponding to $filename") if !@$data_files;
#  throw("found more than one data file corresponding to $filename") if @$data_files >1;
#  if ($data_files->[0]->host->remote()) {
#    $self->reject_message('the associated data file is remote');
#  }
#  return dirname($data_files->[0]->name) . "/$filename";
#}

sub derive_watt_txt_file {
  my ($self, %options) = @_;
  my $filename = $options{filename} or throw("missing filename");
  my $destination_base_dir = $options{destination_base_dir} or throw("missing destination_base_dir");

  #my ($experiment, $filetype) = $filename =~ /(Experiment_\d+)_-_(\w+).txt/;
  my ($experiment, $filetype) = $filename =~ /(\S+)_-_(\w+).txt/;
  if (!$filetype) {
    ($experiment, $filetype) = $filename =~ /(\S+)-(PlateResults).txt/;
  }
  return undef if !$filetype;
  $experiment =~ s/-Objects_Population//;

  $filetype eq lc($filetype);
  if ($experiment eq 'Experiment_1') {
    return "$destination_base_dir/cellbiol-fn/20140424_5samples/hipsci.cellbiol-fn.5samples.20140424.$filetype.txt";
  }
  if ($experiment eq 'Experiment_2') {
    return "$destination_base_dir/cellbiol-fn/20140501_5samples/hipsci.cellbiol-fn.4samples.20140501.$filetype.txt";
  }
  if ($experiment eq 'Experiment3') {
    return "$destination_base_dir/cellbiol-fn/20140528a_4samples/hipsci.cellbiol-fn.4samples.20140528a.$filetype.txt";
  }
  if ($experiment eq 'Experiment_4') {
    return "$destination_base_dir/cellbiol-fn/20140519_6samples/hipsci.cellbiol-fn.6samples.20140519.$filetype.txt";
  }
  if ($experiment eq 'Experiment_5') {
    return "$destination_base_dir/cellbiol-fn/20140528b_4samples/hipsci.cellbiol-fn.4samples.20140528b.$filetype.txt";
  }
  if ($experiment eq '20140521FF') {
    return "$destination_base_dir/cellbiol-fn/20140521_7samples_E8/hipsci.cellbiol-fn.7samples_E8.20140521.$filetype.txt";
  }
  if ($experiment eq '20140530FF') {
    return "$destination_base_dir/cellbiol-fn/20140530_6samples_E8/hipsci.cellbiol-fn.6samples_E8.20140530.$filetype.txt";
  }
  if ($experiment eq 'Edge-lid1') {
    return "$destination_base_dir/cellbiol-fn/edge_lid/20140522_8samples/hipsci.cellbiol-fn.8samples.20140522.edge_lid.$filetype.txt";
  }
  if ($experiment eq 'Edge-lid2') {
    return "$destination_base_dir/cellbiol-fn/edge_lid/20140415_8samples/hipsci.cellbiol-fn.8samples.20140415.edge_lid.$filetype.txt";
  }
  if ($experiment eq 'Edge-Seal1') {
    return "$destination_base_dir/cellbiol-fn/edge_seal/20140522_8samples/hipsci.cellbiol-fn.8samples.20140522.edge_seal.$filetype.txt";
  }
  if ($experiment eq 'Edge-Seal2') {
    return "$destination_base_dir/cellbiol-fn/edge_seal/20140416_8samples/hipsci.cellbiol-fn.8samples.20140416.edge_seal.$filetype.txt";
  }
  return undef;
}


1;
