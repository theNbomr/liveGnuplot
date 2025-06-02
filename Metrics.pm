#
#   This is the Perl Class for the 'Metrics' objects. 
#   Each Metrics instance defines how a measured paramter is acquired,
#   and logged. The metadata that makes up a Metric instance allow code
#   to establish a connection to a defined data source (MQTT in the 
#   first release), and acquire the data on an ongoing basis. 
#   The acquired data are stored/logged in the specified store(s).
#

package Metrics;

sub new {

my $proto = shift;
my $class = ref( $proto ) || $proto;
my $self = {};

    bless $self, $class;

    my %params = @_;
    foreach my $key ( keys %params ){
        my $value = $params{ $key };
        $self->{ $key } = $value;
        if($verbose ){
            print "Key: $key, Value: $value\n";
        }
    }
    $self->{ stores } = ();

    # Create a curried version of the object method 
    # to use as a callback by non-object code
    # RN does not really understand HOW this works,
    # although I understand why it's needed.
    $self->{ CALLBACK } = $self->curry( 'handler' );
    return $self;
}

#
#   This is some dark-assed voodoo majick. 
#   It allows an arbitrary non-object non-instance code 
#   to make callbacks to the curried object method.
#   See the links in the comments at the top of this file.
#
sub curry { 
    my ( $self, $method_name, @args ) = @_;
    my $method = $self->can( $method_name ) || die "No $method_name method found";
    return sub { $self->$method( @args, @_ ) };
}

sub property {
my $self = shift;
my $property = shift;

    # print "** Metrics property setter/getter ($property) **\n";
    if( @_ ){
        my $value = shift;
        if( $verbose ){
            print "\tSetting Property: $property, Value: $value\n";
        }
        $self->{$property} = $value;
        return $self->{$property};
    }
    else{
        if( exists( $self->{$property} ) ){
            return( $self->{$property} );
        }
        else{
            return undef;
        }
    }
}

sub properties {
my $self = shift;
    my @properties = keys( %{$self} );
    return @properties;
}


sub store {
my $self = shift;

    # my @stores = $self->{ stores };
    if( @_ ){
        # Create a new storage property composed of the type (file, db) and Id.
        if( 2 == scalar( @_ ) ){
            my( $storeType, $storeId ) = @_;
            print "Adding store: $storeType => $storeId \n";
            my %store = ( $storeType => $storeId );
            push @{ $self->{ stores } }, %store;
        }
    }
    return( @{ $self->{ stores } } );
}

#
#   Establish a connection to the specified MQTT Broker, and then
#   build a subscription to the specified topic on the connected broker.
#
sub mqttClientInit {
my $self = shift;
my $broker = shift;
    my  %thisBroker = %{ $broker };
    #if( $main::verbose ){
        print "Launch MQTT Broker: name:", $broker->property( 'name' );
        print ", ip: ",   $broker->property( 'ip' );
        print ", port: ", $broker->property( 'port' ),"\n";
        print "All broker properties: ", join( ", ", $broker->properties() ),"\n";
    #}

    my $brokerIp = $broker->property( 'ip' ).":";
    $brokerIp   .= $broker->property( 'port' );
    #
    #   Connect to the specified broker.
    #
    # if( $main::verbose ){
        print "Broker IP:port (Metrics) ", $brokerIp,"\n";
    # }

    my $mqttClient = Net::MQTT::Simple->new( $brokerIp );
    if( $mqttClient ){
        print "MQTT Broker $brokerIp connection Okay\n"
    }
    else{ 
        die "Could not open MQTT Connection\n";
    }

    #
    #   If there are any logfiles or db's to resolve for this metric,
    #   do it here to reduce overhead in the callback..
    #

    # my $filespec = $self->{ 'logfile' };

    my @stores = @{ $self->{ stores } };  # Stores are treated as a special type of property of a metric

    print "\thandler: ", $self->{ name }, ", (", scalar @stores, ") ", join( ", ", @stores), ", ", "\n";
    while( @stores ){
        my ( $storeType, $storeId ) = @stores;
        print "Store Type: $storeType, Store Name: $storeId\n";
        shift @stores;
        shift @stores;
        if( $storeType eq 'file' ){

            #
            #   StoreId is not a filename; it's a reference to a 'file' top-level type.
            #   We need to lookup the specified file Object. The lookup for that lives 
            #   in the main:: namespace...
            #
            if( %main::fileObjs ){
                print "Main File Lookup: ", join( ", ", sort keys( %main::fileObjs ) ),"\n";
            }
            else{
                print "Cannot access Main File Lookup '\%main::fileObjs'\n";
                die;
            }

            my $fileObj = $main::fileObjs{ $storeId };
            if( !defined( $fileObj ) ){
                die "Cannot lookup file ID $storeId: not defined \n";
            }
            else{
                print "File Obj Metadata: ", join( ", ", sort keys %{ $fileObj } ), "\n";
                my $timeDateStamp = scalar localtime( time );
                $timeDateStamp =~ s/\s/_/g;
                $fileSpec = $fileObj->property( 'directory') . "/" .
                            $fileObj->property( 'basename' ) . "_" .
                            $timeDateStamp . ".log";
                print "Filespec: $fileSpec\n";
                $self->{ 'logfile' } = $fileSpec;
            }
        }
    }

    #
    #   Create a subscription on the already connected broker,
    #   to the specified topic. The callback will be invoked
    #   on each new data event.
    #
    # if( $Main::verbose ){
        print "Subscribing to ", $self->{ 'topic' }, " on broker '$brokerIp'\n";
    # }

    $mqttClient->subscribe( $self->{ 'topic' }, $self->{ 'CALLBACK' } );
    print "Subscription registered\n";
    my $testTopic = "$0/$$"; 
    $testTopic =~ s/^[.\/]*//;
    $testTopic =~ s/\./_/g;
    my $testMessage = '{"timedate":"'.scalar localtime( time ).'"}';
    print "Publish 'Alive' message: Topic: $testTopic, Message: $testMessage\n";
    $mqttClient->publish( $testTopic => $testMessage );
    return( $mqttClient );
}

#
#  For this test case, the topic and message looks like this 
#           (newlines added to JSON for clarity):
#
#  tele/tasmota_F74C1D/SENSOR, {
#         "Time":"2025-05-26T11:58:51",
#         "DS18B20":{
#             "Id":"0000005CBBBA",
#             "Temperature":20.8
#         },
#         "TempUnit":"C"
#     }
#

sub handler($$$){
my $self = shift;
my $topic = shift;
my $message = shift;

    print "Begin MQTT Callback:\n";
    
    my $storeType = 'file';

    if( $storeType eq 'file' ){
        my $fileSpec = $self->{ logfile };
        print "Metric '", $self->{ name }, "' :: '$topic' : \"$message\" ==> $filespec\n";
        print "Updating log file '$fileSpec'\n";
        open( LOG, ">>$fileSpec" ) || die "Cannot open $fileSpec for writing: $!\n";
        print( LOG "'$topic' : $message\n" );
        close( LOG );
    }
    elsif( $storeType eq 'db' ){
        print "Store type 'DB' (not implemented)\n";
    }
 
    # $self->handleStores($topic, $message);
    print "END MQTT Callback\n";
    return '';
}

1;


