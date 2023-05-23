#include "RadioRoute.h"

configuration RadioRouteAppC {}
implementation {
/****** COMPONENTS *****/
  components MainC, RadioRouteC as App;

  components ActiveMessageC;
  components new AMReceiverC(AM_RADIO_COUNT_MSG);
  components new AMSenderC(AM_RADIO_COUNT_MSG);
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components LedsC;

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
  App.Leds -> LedsC;
}