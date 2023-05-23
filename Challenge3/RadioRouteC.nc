#include "Timer.h"
#include "RadioRoute.h"

module RadioRouteC @safe() {
  uses {

    /****** INTERFACES *****/
	interface Boot;

  interface AMControl;
  interface Receive;
  interface AMSend;
  interface Packet;
  interface Timer<TMilli> as Timer0;
  interface Timer<TMilli> as Timer1;
  interface Leds;
  //other interfaces, if needed
  }
}
implementation {

  message_t packet;

  // Variables to store the message to send
  message_t queued_packet;
  uint16_t queue_addr;
  uint16_t time_delays[7]={61,173,267,371,479,583,689}; //Time delay in milli seconds

  bool route_req_sent=FALSE;
  bool route_rep_sent=FALSE;
  bool data_sent=FALSE;

  bool locked;

  uint8_t person_code[8]={1,0,7,0,0,6,5,8};
  uint8_t led_iter = 0;

  radio_route_msg_t data_msg;
  routing_table_t routing_table;

  /*PROTOTYPES*/
  bool actual_send (uint16_t address, message_t* packet);
  bool generate_send (uint16_t address, message_t* packet, uint8_t type);
  void handleData(radio_route_msg_t* rtm);
  void handleRouteReq(radio_route_msg_t* rtm);
  void handleRouteReply(radio_route_msg_t* rtm);
  void initRoutingTable();
  void ledUpdate();


  bool generate_send (uint16_t address, message_t* packet, uint8_t type){
  /*
  *
  * Function to be used when performing the send after the receive message event.
  * It store the packet and address into a global variable and start the timer execution to schedule the send.
  * It allow the sending of only one message for each REQ and REP type
  * @Input:
  *		address: packet destination address
  *		packet: full packet to be sent (Not only Payload)
  *		type: payload message type
  *
  * MANDATORY: DO NOT MODIFY THIS FUNCTION
  */
  	if (call Timer0.isRunning()){
  		return FALSE;
  	}else{
  	if (type == 1 && !route_req_sent ){
  		route_req_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = addres;
  	}else if (type == 2 && !route_rep_sent){
  	  route_rep_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = addres;
  	}else if (type == 0){
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = addres;
  	}
  	}
  	return TRUE;
  }

  event void Timer0.fired() {
  	/*
  	* Timer triggered to perform the send.
  	* MANDATORY: DO NOT MODIFY THIS FUNCTION
  	*/
  	actual_send (queue_addr, &queued_packet);
  }

  bool actual_send (uint16_t address, message_t* packet){
	/*
	* Implement here the logic to perform the actual send of the packet using the tinyOS interfaces
	*/
    if(locked) return FALSE;
    locked = TRUE;
    dbg("send","Sending packet to %d\n", address);
    radio_route_msg_t* rtm = (radio_route_msg_t*) Packet.getPayload(&packet, sizeof(radio_route_msg_t));
    if(rtm == NULL) return FALSE;

    rtm->Sender = TOS_NODE_ID;
    rtm->Destination = address;
    call AMSend.send(address, packet, sizeof(message_t));
  }


  event void Boot.booted() {
    dbg("boot","Application booted.\n");

    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
    initRoutingTable();
    Timer1.startOneShot(FIRST_VALUE_TIMEOUT);
  }

  void initRoutingTable() {
    for(uint8_t i=0; i<MAX_NODES; i++) {
      routing_table[i].node = i+1;
      routing_table[i].next_hop = 0;
      routing_table[i].cost = INFINITY;
    }
  }

  event void AMControl.stopDone(error_t err) {
    /* Fill it ... */
  }

  event void Timer1.fired() {
	/*
	* Implement here the logic to trigger the Node 1 to send the first REQ packet
	*/
    if(TOS_NODE_ID == FIRST_SENDER) {
      radio_route_msg_t* rtm = (radio_route_msg_t*) Packet.getPayload(&packet, sizeof(radio_route_msg_t));
      rtm->Type == DATA;
      rtm->Destination = FIRST_VALUE_DESTINATION;
      rtm->Sender = TOS_NODE_ID;
      rtm->Value = FIRST_VALUE;
      data_msg = *rtm; // TODO: if something broke it's probably this line
      handleData(rtm);
    }
  }

  event message_t* Receive.receive(message_t* bufPtr,
				   void* payload, uint8_t len) {
	/*
	* Parse the receive packet.
	* Implement all the functionalities
	* Perform the packet send using the generate_send function if needed
	* Implement the LED logic and print LED status on Debug
	*/
    if(len != sizeof(radio_route_msg_t)) return bufPtr;
    radio_route_msg_t* rtm = (radio_route_msg_t*) payload;
    ledUpdate();
    switch(payload->Type) {
      case DATA: handleData(rtm); return bufPtr;
      case ROUTE_REQ: handleRouteReq(rtm); return bufPtr;
      case ROUTE_REPLY: handleRouteReply(rtm); return bufPtr;
    }
  }

  void ledUpdate() {
    uint8_t led = person_code[led_iter++] % 3;
    switch(led) {
      case 0:
        Leds.led0Toggle();
      case 1:
        Leds.led1Toggle();
      case 2:
        Leds.led2Toggle();
    }
    if(led_iter == 8) led_iter = 0; // at the end return to the first
  }

  void handleData(radio_route_msg_t* rtm) {
    uint16_t destination = rtm->Destination;
    if (isDestinationReachable(destination)) {
      uint16_t nextHop = getNextHop(destination);
      radio_route_msg_t* rtm_tmp = (radio_route_msg_t*) Packet.getPayload(&packet, sizeof(radio_route_msg_t));
      rtm_tmp->Type = DATA;
      rtm_tmp->Destination = destination;
      rtm_tmp->Sender = TOS_NODE_ID;
      rtm_tmp->Value = rtm->Value;
      generate_send(nextHop, &packet, DATA);
    }
    else {
      radio_route_msg_t* rtm_tmp = (radio_route_msg_t*) Packet.getPayload(&packet, sizeof(radio_route_msg_t));
      rtm_tmp->Type = ROUTE_REQ;
      rtm_tmp->NodeRequested = destination;
      generate_send(AM_BROADCAST_ADDR, &packet, ROUTE_REQ);
    }
  }

  void handleRouteReq(radio_route_msg_t* rtm) {
    uint16_t nodeRequested = rtm->NodeRequested;
    if(nodeRequested != TOS_NODE_ID && !isDestinationReachable(nodeRequested)) {
      // Broadcast the route request
      generate_send(AM_BROADCAST_ADDR, &packet, ROUTE_REQ);
    }
    else if(nodeRequested == TOS_NODE_ID) {
      radio_route_msg_t* rtm = (radio_route_msg_t*) Packet.getPayload(&packet, sizeof(radio_route_msg_t));
      rtm->Type = ROUTE_REPLY;
      rtm->Cost = 1;
      rtm->NodeRequested = TOS_NODE_ID;
      rtm->Sender = TOS_NODE_ID;
      generate_send(AM_BROADCAST_ADDR, &packet, ROUTE_REPLY);
    }
    else if(isDestinationReachable(nodeRequested))) {
      // send route request
      radio_route_msg_t* rtm = (radio_route_msg_t*) Packet.getPayload(&packet, sizeof(radio_route_msg_t));
      rtm->Type = ROUTE_REPLY;
      rtm->Cost = getCost(nodeRequested) + 1;
      rtm->NodeRequested = nodeRequested;
      rtm->Sender = TOS_NODE_ID;
      generate_send(AM_BROADCAST_ADDR, &packet, ROUTE_REPLY);
    }

  }

  void handleRouteReply(radio_route_msg_t* rtm) {
    uint16_t nodeRequested = rtm->NodeRequested;
    if(nodeRequested != TOS_NODE_ID && rtm->Cost < getCost(nodeRequested)) { // if the nodeRequested is unreachable, the cost is INFINITY
        routing_table[nodeRequested-1].Cost = rtm->Cost + 1;
        routing_table[nodeRequested-1].NextHop = rtm->Sender;
        generate_send(AM_BROADCAST_ADDR, &packet, ROUTE_REPLY);
        if(TOS_NODE_ID == FIRST_SENDER && !data_sent) handleData(&data_msg);
    }
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	/* This event is triggered when a message is sent
	*  Check if the packet is sent
	*/
  }

  uint8_t getCost(uint16_t destination) {
    for(uint8_t i=0; i<MAX_NODES; i++) {
      if(routing_table[i].Destination == destination) {
        return routing_table[i].Cost;
      }
    }
  }

  bool isDestinationReachable(uint16_t destination) {
    return getCost(destination) != INFINITY;
  }

  uint16_t getNextHop(uint16_t destination) {
    for(uint8_t i=0; i<MAX_NODES; i++) {
      if(routing_table[i].Destination == destination) {
        return routing_table[i].NextHop;
      }
    }
  }
}