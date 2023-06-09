#include "LightPubSub.h"

configuration LightPubSubAppC {}
implementation {
/****** COMPONENTS *****/
  components MainC, LightPubSubC as App;

  components ActiveMessageC;
  components new AMReceiverC(AM_RADIO_COUNT_MSG);
  components new AMSenderC(AM_RADIO_COUNT_MSG);
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components new TimerMilliC() as Timer2;
  components new TimerMilliC() as Timer3;
  components LedsC;
  components RandomC;
  components SerialPrintfC;
  components SerialStartC;

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
  App.Timer2 -> Timer2;
  App.Timer3 -> Timer3;
  App.Leds -> LedsC;
  App.Random -> RandomC;
}
