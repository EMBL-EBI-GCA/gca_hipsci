#!/usr/bin/env perl

use strict;
use warnings;

use ReseqTrack::Tools::ERAUtils qw(get_erapro_conn);
use File::Find qw();
use File::Spec;
use Env qw(RESEQTRACK_PASS);
use List::Util qw();
use JSON qw();

die "set and export your RESEQTRACK_PASS environment variable" if !$RESEQTRACK_PASS;
my $era_dbuser = 'ops$laura';
my $cram_to_line_file = '/nfs/research2/hipsci/drop/hip-drop/tracked/endodiff/tracking/hipsci.endodiff.cram2donor.tsv';
my $cram_to_well_file = '/nfs/research2/hipsci/drop/hip-drop/tracked/endodiff/tracking/hipsci.endodiff.cram2well.tsv';
my $well_to_bulk_sample_file = '/nfs/research2/hipsci/drop/hip-drop/tracked/endodiff/tracking/hipsci.endodiff.well2bulksample.tsv';

my $cram_to_well = read_cram2well($cram_to_well_file);
my $cram_to_line = read_cram2line($cram_to_line_file);
my $well_to_bulk_sample = read_well2knownline($well_to_bulk_sample_file);

my $biostudy_links = build_links($cram_to_line, $cram_to_well, $well_to_bulk_sample);
my $biostudy_files = build_files();

my $submission = build_submission($biostudy_links, $biostudy_files);
print JSON->new->utf8->encode($submission);

=cut

That's the end of the script. Here's the subroutines....

=cut

sub build_submission {
  my ($links, $files) = @_;
  my $title = 'iPSC to endoderm differentiation experiments from the HipSci project';
  my $description = 'Cultures of induced pluripotent stem cells (iPSC) from the HipSci project were differentiated to the endoderm lineage. The iPSC lines were differentiated i) independently as separate cultures, ii) as a co-culture comprising a mixture of cell lines. At various time points, live cells were FACS sorted from these bulk cultures, plated, and frozen. Each sorted cell taken from the mixed co-culture was later identified by its genetics using RNA sequencing.';
  my @exp_sections;
  my %submission = ( submissions => [{
    type => 'submission',
    accno => 'S-BSST50',
    attributes => [
      { name => 'Title', value => $title, },
    ],
    section => {
      type => 'Study',
      attributes => [
        { name => 'Title', value => $title, },
        { name => 'Description', value => $description, },
        { name => 'Organism', value => 'Homo sapiens', },
        { name => 'Cell type', value => 'Induced pluripotent stem cells; iPSC derived cell line; endodermal cell', },
        { name => 'ReleaseDate', value => '2017-12-12', },
      ],
      subsections => \@exp_sections,
    },
  }]);

  foreach my $exp (List::Util::uniq keys %$files, keys %$links) {
    my %exp_section = (
      type => 'Experiment',
      accno => "experiment_$exp",
      attributes => [
        { name => 'Title', value => "Endoderm differentiation experiment $exp", },
      ],
    );
    if (my $exp_files = $files->{$exp}) {
      $exp_section{files} = $exp_files;
    }
    if (my $exp_links = $links->{$exp}) {
      $exp_section{links} = $exp_links;
    }
    push(@exp_sections, \%exp_section);
  }
  return \%submission;
}

sub read_cram2line {
  my ($filename) = @_;
  my %cram_to_line;
  open my $fh, '<', $filename or die $!;
  LINE:
  while (my $line = <$fh>) {
    next LINE if $line =~ /^#/;
    chomp $line;
    my ($cram, $cell_line) = split("\t", $line);
    $cram_to_line{$cram} = $cell_line;
  }
  close $fh;
  return \%cram_to_line;
}

sub read_cram2well {
  my ($filename) = @_;
  my %cram_to_well;
  open my $fh, '<', $filename or die $!;
  LINE:
  while (my $line = <$fh>) {
    next LINE if $line =~ /^#/;
    chomp $line;
    my @split_line = split("\t", $line);
    @{$cram_to_well{$split_line[0]}}{qw(well experiment day)} = @split_line[1,2,3];
  }
  close $fh;
  return \%cram_to_well;
}

sub read_well2knownline {
  my ($filename) = @_;
  my %well_to_known_line;
  open my $fh, '<', $filename or die $!;
  LINE:
  while (my $line = <$fh>) {
    next LINE if $line =~ /^#/;
    chomp $line;
    my @split_line = split("\t", $line);
    $well_to_known_line{$split_line[0]}{$split_line[1]}{$split_line[2]} = $split_line[3];
  }
  close $fh;
  return \%well_to_known_line;
}

sub build_links {
  my ($cram_to_line, $cram_to_well, $well_to_known_line) = @_;
  my $sql = 'select xmltype.getclobval(r.run_xml), s.biosample_id, st.ega_id
        from run r, experiment e, run_sample rs, sample s, study st
        where r.experiment_id=e.experiment_id
          and r.run_id=rs.run_id
          and s.sample_id=rs.sample_id
          and st.study_id=e.study_id
          and e.study_id=?
          and s.status_id=4 and e.status_id=4 and r.status_id=4';
  my $db = get_erapro_conn($era_dbuser, $RESEQTRACK_PASS, 'ERAPRO');
  $db->dbc->db_handle->{LongReadLen} = 66000;
  my $sth = $db->dbc->prepare($sql);
  my %biosample_links;

  my @studies = (
    { id => 'ERP016000', open_access => 1},
    { id => 'ERP021387', open_access => 0},
  );

  foreach my $study (@studies) {
    $sth->execute($study->{id});
    my $count = 0;
    while (my $ref = $sth->fetchrow_arrayref()) {
      $ref->[0] =~ m{filename="(?:[^"]*/)*([^"/]+).cram"};
      die "did not get filename: $$ref[0]" if !$&;
      my $cram = $1;
      my $link = $biosample_links{$ref->[1]} || {
        url => $study->{open_access} ? $ref->[1] : $ref->[2],
        attributes => {
          'Type' => $study->{open_access} ? 'Gen' : 'EGA',
          'Biosample id' => $ref->[1],
          'Cram files' => [],
        },
      };
      push(@{$link->{attributes}{'Cram files'}}, $cram);
      my $cell_line;
      if ($cram_to_well->{$cram}) {
        my ($well, $day, $exp) = @{$cram_to_well->{$cram}}{qw(well day experiment)};
        foreach my $key (qw(well day experiment)) {
          if (defined $cram_to_well->{$cram}{$key}) {
            $link->{attributes}{ucfirst($key)} = $cram_to_well->{$cram}{$key};
          }
        }
        $cell_line = $well_to_known_line->{$exp}{$day}{$well};
      }

      if ($cell_line) {
        $link->{attributes}{'Description'} = ($cell_line =~ /^mixed/)
                             ? "50 cells (approx) from co-culture of multiple cell lines"
                             : "50 cells (approx) of $cell_line";
      }
      else {
        $link->{attributes}{'Description'} = "single cell from co-culture of multiple cell lines";
        if (my $line = $cram_to_line->{$cram}) {
          $link->{attributes}{'Identity inferred by RNA-seq'} = $line;
        }
      }
      $biosample_links{$ref->[1]} = $link;
      $count += 1;
    }
  }
  $sth->finish;

  my %experiment_links;
  while (my ($biosample_id, $link) = each %biosample_links) {
    my $exp = $link->{attributes}{Experiment};
    next if !$exp;
    $link->{attributes}{'Cram files'} = join(',', @{$link->{attributes}{'Cram files'}});
    my @attr;
    while (my ($key, $val) = each %{$link->{attributes}}) {
      push(@attr, {name => $key, value => $val});
    }
    $link->{attributes} = \@attr;
    push(@{$experiment_links{$exp}}, $link);
  }
  return \%experiment_links;
}

sub build_files {
  my $dir = "/nfs/research2/hipsci/drop/hip-drop/tracked/endodiff/";
  my %files;
  File::Find::find(sub {
    return if -d $_ || ! /\.fcs$/;
    my @split_name = split(/\./);
    my ($experiment) = $split_name[2] =~ /exp(\d+)/;
    my ($day) = $split_name[4] =~ /day(\d)/;
    my $type = $split_name[5];
    my ($well) = $split_name[6] =~ /([A-Z](?:\d+_[A-Z])*\d+)/;
    if ($well) {
      $well =~ s/_/,/g;
    } elsif ($split_name[6] =~ /single_cells/) {
      $well = 'multiple wells';
    }
    my ($rep) = $split_name[6] =~ /rep(\d+)/;

    if ($split_name[3] =~ /mixed/) {
      if ($split_name[5] =~ /(.*)_bulk/) {
        $split_name[3] .= " $1";
      }
      $split_name[3] =~ s/_/ /g;
    }


    my %file = (
      path => File::Spec->abs2rel($File::Find::name, $dir),
      type => 'file',
      size => -s $_,
      attributes => [
        { name => 'Experiment', value => $experiment },
        { name => 'Day', value => $day },
        { name => 'Sample', value => $split_name[3] },
        { name => 'FACS type', value => $type =~ /indexed/ ? 'indexed sort onto plate' : 'bulk culture' }
      ],
    );

    if (defined $rep) {
      push(@{$file{attributes}}, {name => 'Replicate', value => $rep});
    }
    if (defined $well) {
      push(@{$file{attributes}}, {name => 'Well', value => $well});
    }
    push(@{$files{$experiment}}, \%file);

  }, $dir);
  return \%files;
}

