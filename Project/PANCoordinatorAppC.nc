#include "PANCoordinator.h"

configuration{}
implementation {
    components MainC, PANCoordinatorC as App;
    components new TimerMilliC() as Timer0;
    components new TimerMilliC() as Timer1;
    components new AMReceiverC();
    components new AMSenderC();
    components ActiveMessageC;

    App.Boot -> MainC.Boot;

    App.Timer0 -> Timer0;
    App.Timer1 -> Timer1;
    App.AMSend -> AMSenderC;
    App.Receive -> AMReceiverC;
    App.SplitControl -> ActiveMessageC;
}