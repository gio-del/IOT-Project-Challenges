#include "PubSub.h"

configuration ClientNodeAppC {}
implementation {
    components MainC, ClientNodeC as App;
    components new TimerMilliC() as Timer0;
    components new TimerMilliC() as Timer1;
    components new AMReceiverC();
    components new AMSenderC();
    components ActiveMessageC;
    components RandomC;

    App.Boot -> MainC.Boot;
    App.Timer0 -> TimerMilliC;
    App.Timer1 -> TimerMilliC;
    App.Receive -> AMReceiverC;
    App.AMSend -> AMSenderC;
    App.SplitControl -> ActiveMessageC;
    App.Random -> RandomC;
}
