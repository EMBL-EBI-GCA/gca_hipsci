package HipSciRegistry;

use strict;
use warnings;

use JSON;
use HTTP::Request::Common qw/GET DELETE POST/;
use LWP::UserAgent;

my $server = "https://beta.trackhubregistry.org";
my $ua = LWP::UserAgent->new;
$| = 1; 

sub new {

  my $class = shift;
  my $username  = shift;
  my $password = shift;
  my $visibility = shift; # in the THR I can register track hubs but being not publicly available. This is useful for testing. I can only see the track hubs with visibility "hidden" in my THR account, they are not seen by anyone else
  
  defined $username and $password
    or die "Some required parameters are missing in the constructor in order to construct a Registry object\n";

  my $self = {
    username  => $username ,
    pwd => $password,
    visibility => $visibility
  };

  my $auth_token = eval {registry_login($username, $password) };
  if ($@) {
    print STDERR "Couldn't login using username $username and password $password: $@\n";
    die;
  }
  $self->{auth_token} = $auth_token;

  return bless $self,$class;
}

sub register_track_hub{
 
  my $self = shift;

  my $track_hub_id = shift;
  my $trackHub_txt_file_url = shift;

  defined $track_hub_id and $trackHub_txt_file_url
    or print "Some required parameters are missing in order to register track hub the Track Hub Registry\n" and return 0;

  my $return_string;

  my $username = $self->{username};
  my $auth_token = $self->{auth_token};

  my $url = $server . '/api/trackhub';

  my $request ;

  if($self->{visibility} eq "public"){

    $request = POST($url,'Content-type' => 'application/json',
   #  assemblies => { "$assembly_name" => "$assembly_accession" } }));
    'Content' => to_json({ url => $trackHub_txt_file_url}));

  }else{  # hidden
    $request = POST($url,'Content-type' => 'application/json',
   #  assemblies => { "$assembly_name" => "$assembly_accession" } }));
    'Content' => to_json({ url => $trackHub_txt_file_url, public => 0 }));
  }
  $request->headers->header(user => $username);
  $request->headers->header(auth_token => $auth_token);

  my $response = $ua->request($request);

  my $response_code= $response->code;

  if($response_code == 201) {

   $return_string= "  ..$track_hub_id is Registered\n";

  }else{ 

    $return_string= "Couldn't register track hub with the first attempt: " .$track_hub_id.$response->code."\t" .$response->content."\n";

    my $flag_success=0;

    for(my $i=1; $i<=10; $i++) {

      $return_string = "\t".$return_string. $i .") Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      $response = $ua->request($request);
      $response_code= $response->code;

      if($response_code == 201){
        $flag_success =1 ;
        $return_string = $return_string. "  ..$track_hub_id is Registered\n";
        last;
      }

    }

    if($flag_success ==0){

      $return_string = $return_string . " ..Didn't manage to register the track hub $track_hub_id , check in STDERR\n";
      print STDERR $track_hub_id."\t".$response->code."\t". $response->content."\n\n";
    }

  }
  return $return_string;
}

sub delete_track_hub{

  my $self = shift;
  my $track_hub_id = shift;

  defined $track_hub_id
    or print "Track hub id parameter required to remove track hub from the Track Hub Registry\n" and return 0;

  my $auth_token = eval { $self->{auth_token} };

  my %trackhubs;
  my $url = $server . '/api/trackhub';

  if ($track_hub_id eq "all"){
    %trackhubs= %{$self->give_all_Registered_track_hub_names()};
    
  }else{
    $trackhubs{$track_hub_id} = 1;
  }

  my $counter_of_deleted=0;

  foreach my $track_hub (keys %trackhubs) {

    $counter_of_deleted++;
    if($track_hub_id eq "all"){
      print "$counter_of_deleted";
    }
    print "\tDeleting trackhub ". $track_hub."\t";
    my $request = DELETE("$url/" . $track_hub);

    $request->headers->header(user => $self->{username});
    $request->headers->header(auth_token => $auth_token);
    my $response = $ua->request($request);
    my $response_code= $response->code;

    if ($response->code != 200) {
      $counter_of_deleted--;
      print "..Error- couldn't be deleted - check STDERR.\n";
      printf STDERR "\n\tCouldn't delete track hub from THR : " . $track_hub . " with response code ".$response->code . " and response content ".$response->content." in script " .__FILE__. " line " .__LINE__."\n";
    } else {
      print "..Done\n";
    }
  }
}

sub registry_login {

  my $user = shift;
  my $pass = shift;
  
  defined $server and defined $user and defined $pass
    or die "Some required parameters are missing when trying to login in the TrackHub Registry\n";

  my $endpoint = '/api/login';
  my $url = $server.$endpoint; 

  my $request = GET($url);
  $request->headers->authorization_basic($user, $pass);

  my $response = $ua->request($request);
  my $auth_token;

  if ($response->is_success) {
    $auth_token = from_json($response->content)->{auth_token};
  } else {
    die "Unable to login to Registry, reason: " .$response->code ." , ". $response->content."\n";
  }
  
  defined $auth_token or die "Undefined authentication token when trying to login in the Track Hub Registry\n";
  return $auth_token;

}

1;