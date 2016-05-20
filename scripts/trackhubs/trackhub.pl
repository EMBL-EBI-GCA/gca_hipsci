#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use Registry;


my @exomeseq;
my ($registry_user_name,$registry_pwd);
my ($server_dir_full_path, $server_url, $from_scratch);

GetOptions(
  "THR_username=s"             => \$registry_user_name,
  "THR_password=s"             => \$registry_pwd,
  "server_dir_full_path=s"     => \$server_dir_full_path,
  "server_url=s"               => \$server_url,  
  "exomeseq=s"                 => \@exomeseq,
  "do_track_hubs_from_scratch" => \$from_scratch,  # flag
);

if(!$registry_user_name or !$registry_pwd or !$server_dir_full_path or !$server_url){
  die "\nMissing required options\n";
}

my %cell_lines;

foreach my $enaexomeseq (@exomeseq){
  open my $fh, '<', $enaexomeseq or die $!;
  <$fh>;
  while (my $line = <$fh>) {
    next unless $line =~ /^ftp/;
    chomp $line;
    my @parts = split("\t", $line);
    if (exists($cell_lines{$parts[3]})){
      push($cell_lines{$parts[3]}, $parts[0])
    }else{
      $cell_lines{$parts[3]} = [$parts[0]]
    }
  }
  close $fh;
}

#my $registry_obj = Registry->new($registry_user_name, $registry_pwd);

print $server_dir_full_path, "\n";

if (!-d $server_dir_full_path) {
  my @args = ("mkdir", "$server_dir_full_path", "arg2");
  system(@args) == 0 or die "system @args failed: $?";
}



