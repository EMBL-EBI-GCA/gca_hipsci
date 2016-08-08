
package ReseqTrack::Tools::HipSci::ElasticsearchClient;
use namespace::autoclean;
use Moose;
use Search::Elasticsearch;

has 'host' => (is => 'ro', isa => 'Str', required => 1);
has '_client' => (
          is => 'ro',
          isa => 'Search::Elasticsearch::Client::1_0::Direct',
          lazy => 1,
          builder => '_build_client'
        );

sub _build_client {
  my ($self) = @_;
  return Search::Elasticsearch->new(nodes => $self->host, client => '1_0::Direct');
}

sub fetch_line_by_name {
  my ($self, $name) = @_;
  my $es_line;
  eval { $es_line = $self->_client->get(
    index => 'hipsci',
    type => 'cellLine',
    id => $name,
  );};
  return $es_line;
}

sub fetch_donor_by_name {
  my ($self, $name) = @_;
  my $donor;
  eval {$donor = $self->_client->get(
    index => 'hipsci',
    type => 'donor',
    id => $name,
  );};
  return $donor;
}

sub fetch_line_by_biosample_id {
  my ($self, $biosample_id) = @_;
  my $results = $self->_client->search(
    index => 'hipsci',
    type => 'cellLine',
    body => {
      query => {
        filtered => {
          filter => {
            term => {
              bioSamplesAccession => $biosample_id
            }
          }
        }
      }
    }
  );
  return $results->{hits}{hits} ? $results->{hits}{hits}[0] : undef;
}

sub fetch_donor_by_biosample_id {
  my ($self, $biosample_id) = @_;
  my $results = $self->_client->search(
    index => 'hipsci',
    type => 'donor',
    body => {
      query => {
        filtered => {
          filter => {
            term => {
              bioSamplesAccession => $biosample_id
            }
          }
        }
      }
    }
  );
  return $results->{hits}{hits} ? $results->{hits}{hits}[0] : undef;
}

sub index_line {
  my ($self, %args) = @_;
  my %es_args = (index => 'hipsci', type => 'cellLine', body => $args{body});
  if ($args{id}) {
    $es_args{id} = $args{id};
  }
  return $self->_client->index(%es_args);
}

sub index_donor {
  my ($self, %args) = @_;
  my %es_args = (index => 'hipsci', type => 'donor', body => $args{body});
  if ($args{id}) {
    $es_args{id} = $args{id};
  }
  return $self->_client->index(%es_args);
}

sub index_file {
  my ($self, %args) = @_;
  my %es_args = (index => 'hipsci', type => 'file', body => $args{body});
  if ($args{id}) {
    $es_args{id} = $args{id};
  }
  return $self->_client->index(%es_args);
}

sub call {
  my ($self, $sub_name, %params) = @_;
  return $self->_client->$sub_name(%params);
}

__PACKAGE__->meta->make_immutable;

1;
