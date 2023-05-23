#include "RadioRoute.h"

configuration RadioRouteAppC {}
implementation {
/****** COMPONENTS *****/
  components MainC, RadioRouteC as App;

  components ActiveMessageC;
  compontents new AMReceiverC(AM_RADIO_COUNT_MSG);
  compontents new AMSenderC(AM_RADIO_COUNT_MSG);
  compontents new TimerMilliC() as Timer0;
  compontents new TimerMilliC() as Timer1;
  compontents Leds;

  /****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;

  /****** Wire the other interfaces down here *****/
  //AM interface
  App.AMControl -> ActiveMessageC;
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  App.Packet -> AMSenderC;
  App.Timer0 -> Timer0;
  App.Timer1 -> Timer1;
  App.Leds -> Leds;
}


