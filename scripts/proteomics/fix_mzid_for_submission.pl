#!/usr/bin/env perl

use strict;

use File::Basename qw(dirname fileparse);
use Getopt::Long;
use XML::LibXML;

my ($mzid, $mzML);

&GetOptions( 
	    'mzid=s'      => \$mzid,
	    'mzML=s'      => \$mzML,
    );

die "no mzid file" if !$mzid;

my $mzid_nsuri = 'http://psidev.info/psi/pi/mzIdentML/1.1';
my $xc = XML::LibXML::XPathContext->new();
$xc->registerNs('mzid', $mzid_nsuri);


# Fix pre="[" to pre="."
my $doc = XML::LibXML->load_xml( location => $mzid);
foreach my $node ($xc->findnodes('./mzid:MzIdentML/mzid:SequenceCollection/mzid:PeptideEvidence[@pre="["]', $doc)) {
  $node->setAttribute('pre' => '-');
}

# Fix post="]" to post="."
foreach my $node ($xc->findnodes('./mzid:MzIdentML/mzid:SequenceCollection/mzid:PeptideEvidence[@post="]"]', $doc)) {
  $node->setAttribute('post' => '-');
}

# Fix database name so it is not a system-specific file path
foreach my $db ($xc->findnodes('./mzid:MzIdentML/mzid:DataCollection/mzid:Inputs/mzid:SearchDatabase', $doc)) {
  my $location = $db->getAttribute('location');
  $location =~ s{.*/}{};
  $db->setAttribute('location' => "file://$location");
  foreach my $db_user_param ($xc->findnodes('./mzid:DatabaseName/mzid:userParam', $db)) {
    my $db_name = $db_user_param->getAttribute('name');
    $db_name =~ s{.*/}{};
    $db_user_param->setAttribute('name' => $db_name);
  }
}

# Fix input mzml filename
foreach my $db ($xc->findnodes('./mzid:MzIdentML/mzid:DataCollection/mzid:Inputs/mzid:SpectraData', $doc)) {
  my $location = fileparse($mzML);
  $db->setAttribute('location' => "file://$location");
}

# Fix residues='N-term' to residues='.'
foreach my $modification ($xc->findnodes('./mzid:MzIdentML/mzid:AnalysisProtocolCollection/mzid:SpectrumIdentificationProtocol/mzid:ModificationParams/mzid:SearchModification[@residues="N-term"]', $doc)) {
  $modification->setAttribute('residues' => '.');
}

# Fix the sequence order of elements under SpectrumIdentificationProtocol
foreach my $sidp ($xc->findnodes('./mzid:MzIdentML/mzid:AnalysisProtocolCollection/mzid:SpectrumIdentificationProtocol', $doc)) {
  my @child_nodes = $sidp->childNodes();
  $sidp->removeChildNodes;
  foreach my $node_name (qw(SearchType AdditionalSearchParams ModificationParams Enzymes MassTable FragmentTolerance ParentTolerance Threshold DatabaseFilters DatabaseTranslation)) {
    foreach my $child ( grep {$_->nodeName eq $node_name} @child_nodes) {
      $sidp->appendChild($child);
    }
  }
}

print $doc->toString;
