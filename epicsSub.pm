use strict;
use warnings;

use lib '/usr1/local/epics/base-3.16/epics-base/lib/perl/';
use CA;

sub caget {
my $pv = shift;

    
}

sub caSub {
my $epicsPv = shift;
my $epicsCaServerPort = shift;
my $epicsCaRepeaterPort = shift;
my $epicsCaCallback = shift;

    print "EPICS_CA_REPEATER_PORT: $ENV{ EPICS_CA_REPEATER_PORT }\n";
    print "EPICS_CA_SERVER_PORT:   $ENV{ EPICS_CA_SERVER_PORT }\n";
    $ENV{EPICS_CA_REPEATER_PORT} = $epicsCaRepeaterPort;
    $ENV{EPICS_CA_SERVER_PORT} = $epicsCaServerPort;
    print "EPICS_CA_REPEATER_PORT: $ENV{ EPICS_CA_REPEATER_PORT }\n";
    print "EPICS_CA_SERVER_PORT:   $ENV{ EPICS_CA_SERVER_PORT }\n";

    my $chan = CA->new( $epicsPv );
    CA->pend_io(1);     # pend_io() only waits for up to maximum time.
    my @access = ('no ', '');
    printf "    PV name:       %s\n", $chan->name;
    printf "    Data type:     %s\n", $chan->field_type;
    printf "    Element count: %d\n", $chan->element_count;
    printf "    Host:          %s\n", $chan->host_name;
    printf "    State:         %s\n", $chan->state;
    printf "    Access:        %sread, %swrite\n",
        $access[$chan->read_access], $access[$chan->write_access];

    die "PV not found!" unless $chan->is_connected;
    $chan->get();
    CA->pend_io(1);     # pend_io() only waits for up to maximum time.

    # return();

    #$chan->create_subscription('v', \&callback, 'DBR_TIME_DOUBLE');

    #
    #   epicsCaCallback needs to be a curried coderef to a subroutin in 
    #   the callers (Metrics) namespace.
    #
    $chan->create_subscription('v', $epicsCaCallback, 'DBR_TIME_DOUBLE');
    # CA->pend_event(10);
    #                           pend_event(0) blocks forever...
    CA->pend_event(1.0);      # pend_event() always waits for the full, specified, time.
    print "Done\n";

    return();
}

    # sub caCallback {
    #     my ($chan, $status, $data) = @_;


    #     # print join( ", ", sort keys %{ $chan } ), "\n";
    #     if ($status) {
    #         printf "%-30s %s\n", $chan->name, $status;
    #     } else {
    #         printf "    Value:         %g\n", $data->{value};
    #         printf "    Timestamp:     %d.%09d\n",
    #             $data->{stamp}, $data->{stamp_fraction};
    #         if( defined( $data->{severity} ) ){
    #             printf "    Severity:      %s\n", $data->{severity};
    #         }
    #     }
    #     # print join( ", ", sort keys %{ $data } ), "\n\n";
    # }

1;
