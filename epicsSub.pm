use strict;
use warnings;

use lib '/usr1/local/epics/base-3.16/epics-base/lib/perl/';
use CA;

sub caget {
my $pv = shift;

    
}

sub camonitor {
my $pv = shift;


    print "EPICS_CA_REPEATER_PORT: $ENV{ EPICS_CA_REPEATER_PORT }\n";
    print "EPICS_CA_SERVER_PORT:   $ENV{ EPICS_CA_SERVER_PORT }\n";

    $ENV{EPICS_CA_REPEATER_PORT} = 9101;
    $ENV{EPICS_CA_SERVER_PORT} = 9102;
    
    # my $pv = 'RN:TEST1:CALC1';
    if( @_ ){
        $pv = shift;
    }

    my $chan = CA->new( $pv );
    CA->pend_io(1);
    my @access = ('no ', '');
    printf "    PV name:       %s\n", $chan->name;
    printf "    Data type:     %s\n", $chan->field_type;
    printf "    Element count: %d\n", $chan->element_count;
    printf "    Host:          %s\n", $chan->host_name;
    printf "    State:         %s\n", $chan->state;
    printf "    Access:        %sread, %swrite\n",
        $access[$chan->read_access], $access[$chan->write_access];

    die "PV not found!" unless $chan->is_connected;
    $chan->get;
    CA->pend_io(1);
    printf "    Value:         %s\n", $chan->value;

    print "chid: $chan \n";
    # print "chid: ", join( ", ", sort keys %{ $chan } ),"\n";
    $chan->create_subscription('v', \&callback, 'DBR_TIME_DOUBLE');
    CA->pend_event(10);

}


sub callback {
    my ($chan, $status, $data) = @_;


    # print join( ", ", sort keys %{ $chan } ), "\n";
    if ($status) {
        printf "%-30s %s\n", $chan->name, $status;
    } else {
        printf "    Value:         %g\n", $data->{value};
        printf "    Timestamp:     %d.%09d\n",
            $data->{stamp}, $data->{stamp_fraction};
        if( defined( $data->{severity} ) ){
            printf "    Severity:      %s\n", $data->{severity};
        }
    }
    # print join( ", ", sort keys %{ $data } ), "\n\n";
}

1;
