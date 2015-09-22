
package ReseqTrack::Hive::HipSci::FileRelease::Move;

use strict;
use File::Basename qw(fileparse dirname);
use ReseqTrack::Tools::Exception qw(throw);
use ReseqTrack::Tools::HipSci::CGaPReport::CGaPReportUtils qw(read_cgap_report);

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

  my ($cgap_ips_lines, $cgap_tissues) = @{read_cgap_report()}{qw(ips_lines tissues)};

  my $derive_path_options = $self->param('derive_path_options');
  my $controlled_base_dir = $derive_path_options->{controlled_base_dir};
  my $free_base_dir = $derive_path_options->{free_base_dir};
  throw("this module needs a controlled_base_dir") if ! defined $controlled_base_dir;
  throw("this module needs a free_base_dir") if ! defined $free_base_dir;

  my ($filename, $incoming_dirname) = fileparse($dropbox_path);

  my $destination;
  my $destination_base_dir = $incoming_dirname =~ m{/incoming/lamond} ? $free_base_dir
        : $self->derive_destination_base_dir(
              filename =>$filename, 
              controlled_base_dir => $controlled_base_dir, free_base_dir => $free_base_dir,
              cgap_ips_lines => $cgap_ips_lines, cgap_tissues => $cgap_tissues);

  if ($incoming_dirname =~ m{/incoming/keane}) {
    if ($filename =~ /\.vcf(\.gz)?$/) {
      $destination = $self->derive_keane_vcf(filename => $filename, destination_base_dir => $destination_base_dir, incoming_dirname => $incoming_dirname);
    }
    elsif ($filename =~ /\.bam$/) {
      $destination = $self->derive_keane_bam(filename => $filename, destination_base_dir => $destination_base_dir);
    }
    elsif ($filename =~ /\.gtc$/) {
      $destination = $self->derive_keane_gtc(filename => $filename, destination_base_dir => $destination_base_dir);
    }
    elsif ($filename =~ /\.idat$/) {
      $destination = $self->derive_keane_idat(filename => $filename, destination_base_dir => $destination_base_dir, incoming_dirname => $incoming_dirname);
    }
    elsif ($filename =~ /\.(txt)|(csv)$/) {
      $destination = $self->derive_keane_txt(filename => $filename, destination_base_dir => $destination_base_dir, incoming_dirname => $incoming_dirname);
    }
    throw("cannot derive path for $filename") if !$destination;
  }
  elsif ($incoming_dirname =~ m{/incoming/lamond} ){
    if ($filename =~ /\.raw$/) {
      $destination = $self->derive_lamond_raw_file(filename => $filename, destination_base_dir => $free_base_dir);
    }
    if ($filename =~ /\.mzML$/) {
      $destination = $self->derive_lamond_mzml_file(filename => $filename, destination_base_dir => $free_base_dir);
    }
    if ($filename =~ /\.txt$/ || $filename =~ /\.pdf$/) {
      $destination = $self->derive_lamond_processed_file(filename => $filename, destination_base_dir => $free_base_dir);
    }
  }
  elsif ($incoming_dirname =~ m{/incoming/watt} ){
    if ($filename =~ /\.txt$/) {
      $destination = $self->derive_watt_txt_file(filename => $filename, destination_base_dir => $free_base_dir);
    }
  }
  elsif ($incoming_dirname =~ m{/incoming/stegle} ){
    if ($filename =~ /\.featureXML$/) {
      $destination = $self->derive_featurexml_file(filename => $filename, destination_base_dir => $destination_base_dir);
    }
  }
  elsif ($incoming_dirname =~ m{/incoming/cellomics} ){
      $destination = $self->derive_cellomics_file(filename => $filename, destination_base_dir => $free_base_dir);
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

sub derive_destination_base_dir {
  my ($self, %options) = @_;
  my $filename = $options{filename} or throw("missing filename");
  my $controlled_base_dir = $options{controlled_base_dir} or throw("missing controlled_base_dir");
  my $free_base_dir = $options{free_base_dir} or throw("missing free_base_dir");
  my $cgap_ips_lines = $options{cgap_ips_lines} or throw("missing cgap_ips_lines");
  my $cgap_tissues = $options{cgap_tissues} or throw("missing cgap_tissues");

  my $donor = List::Util::first {$_} map {$_->donor} (
        (grep {my $tissue_name = $_->name; $filename =~ /$tissue_name\./} @$cgap_tissues),
        (map {$_->tissue} grep {my $line_name = $_->name; $filename =~ /$line_name\./} @$cgap_ips_lines)
      );
  throw "no donor for $filename" if !$donor;
  my $hmdmc = $donor->hmdmc;
  return $controlled_base_dir if $hmdmc eq 'H1288';
  return $controlled_base_dir if $hmdmc eq '13_058';
  return $controlled_base_dir if $hmdmc eq '14_001';
  return $controlled_base_dir if $hmdmc eq '14_025';
  return $controlled_base_dir if $hmdmc eq '14_036';
  
  return $free_base_dir if $hmdmc eq '13_042';
  throw("did not recognise hmdmc $hmdmc for filename $filename");
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

  if ($filename =~ /HPSI\d{4}[a-z]+-[a-z]{4}(?:_\d+)?/) {
    my $sample = $&;

    if ($filename =~ /\.SureSelect_HumanAllExon[^\.]*\.mpileup/) {
      return "$destination_base_dir/exomeseq/vcf/$sample/$filename";
    }
    elsif ($filename =~ /\.HumanCoreExome.*\.imputed/) {
      return "$destination_base_dir/gtarray/imputed_vcf/$sample/$filename";
    }
    elsif ($filename =~ /\.HumanCoreExome/) {
      return "$destination_base_dir/gtarray/vcf/$sample/$filename";
    }
    elsif ($filename =~ /\.SureSelect_HumanAllExon[^\.]*\.mpileup/) {
      return "$destination_base_dir/exomeseq/vcf/$sample/$filename";
    }
    elsif ($filename =~ /\.SureSelect_HumanAllExon[^\.]*\.imputed/) {
      return "$destination_base_dir/exomeseq/imputed_vcf/$sample/$filename";
    }
    else {
      return undef;
    }
  }
  elsif ($filename =~ /^hipsci\./) {
    my $incoming_dirname = $options{incoming_dirname} or throw("missing incoming_dir_name");
    my ($dirname) = $incoming_dirname =~ m{keane/data/(.*)};
    return "$destination_base_dir/$dirname/$filename";
  }
  else {
    throw("could not derive new filename for $filename");
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
  my $incoming_dirname = $options{incoming_dirname} or throw("missing incoming_dir_name");
  my ($dirname) = $incoming_dirname =~ m{gtarray/primary_data/(.*)};
  throw("did not get a dirname") if !$dirname;
  if ($filename =~ /\.gtarray\.\d{8}/) {
    return "$destination_base_dir/gtarray/primary_data/$dirname/$filename";
  }
  if ($filename =~ /\.gexarray\.\d{8}/) {
    return "$destination_base_dir/gexarray/primary_data/$dirname/$filename";
  }
  if ($filename =~ /\.mtarray\.\d{8}/) {
    return "$destination_base_dir/mtarray/primary_data/$dirname/$filename";
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
  my ($cell_line_name) = $filename =~ /^([^.]+)\./;
  throw("did not recognise cell line name $filename") if !$cell_line_name;
  my $incoming_dirname = $options{incoming_dirname} or throw("missing incoming_dir_name");
  if ($filename =~ /\.mtarray\.Human/) {
    return "$destination_base_dir/mtarray/text_files/$cell_line_name/$filename";
  }
  if ($filename =~ /\.gexarray\.Human/) {
    my ($dirname) = $incoming_dirname =~ m{gexarray/genome_studio_files/(.*)};
    return "$destination_base_dir/gexarray/genome_studio_files/$dirname/$filename";
  }
  else {
    return undef;
  }
}


sub derive_lamond_raw_file {
  my ($self, %options) = @_;
  my $filename = $options{filename} or throw("missing filename");
  print "filename $filename\n";
  my $destination_base_dir = $options{destination_base_dir} or throw("missing destination_base_dir");
  my $file_details = $self->param('file');
  my $cell_line_name = $file_details->{'cell_line'};
  #my $donor_name = $self->derive_donor($cell_line_name);
  #return "$destination_base_dir/proteomics/raw_data/$donor_name/$cell_line_name/$filename";
  return "$destination_base_dir/proteomics/raw_data/$cell_line_name/$filename";
}

sub derive_lamond_mzml_file {
  my ($self, %options) = @_;
  my $filename = $options{filename} or throw("missing filename");
  print "filename $filename\n";
  my $destination_base_dir = $options{destination_base_dir} or throw("missing destination_base_dir");
  my $file_details = $self->param('file');
  my $cell_line_name = $file_details->{'cell_line'};
  #my $donor_name = $self->derive_donor($cell_line_name);
  #return "$destination_base_dir/proteomics/raw_data/$donor_name/$cell_line_name/$filename";
  return "$destination_base_dir/proteomics/raw_open_data/$cell_line_name/$filename";
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

sub derive_featurexml_file {
  my ($self, %options) = @_;
  my $filename = $options{filename} or throw("missing filename");
  my $destination_base_dir = $options{destination_base_dir} or throw("missing destination_base_dir");
  my $file_details = $self->param('file');
  my $cell_line_name = $file_details->{'cell_line'};
  my $donor_name = $self->derive_donor($cell_line_name);
  return "$destination_base_dir/proteomics/openMS/$donor_name/$cell_line_name/features/$filename";
}

sub derive_cellomics_file {
  my ($self, %options) = @_;
  my $filename = $options{filename} or throw("missing filename");
  my $destination_base_dir = $options{destination_base_dir} or throw("missing destination_base_dir");
  my ($cell_line_name) = $filename =~ /([\w-]+)/;
  die "no cell line name for $filename" if !$cell_line_name;
  my $tissue_name = $cell_line_name;
  $tissue_name =~ s/_\d+$//;
  die "no tissue name for $filename" if !$tissue_name;
  return "$destination_base_dir/cellomics/raw_data/$tissue_name/$cell_line_name/$filename";
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
