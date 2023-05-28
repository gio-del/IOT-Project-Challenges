#include "Timer.h"
#include "RadioRoute.h"

module RadioRouteC @safe() {
  uses {

    /****** INTERFACES *****/
	interface Boot;

  interface SplitControl as AMControl;
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

  /*Routing Table Utility Functions*/
  uint8_t getCost(uint16_t destination);
  uint16_t getNextHop(uint16_t destination);
  bool isDestinationReachable(uint16_t destination);


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
  		queue_addr = address;
  	}else if (type == 2 && !route_rep_sent){
  	  route_rep_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 0){
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
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
    if(locked) {
    	return FALSE;
    }
    else {
    	radio_route_msg_t* rtm = (radio_route_msg_t*)call Packet.getPayload(packet, sizeof(radio_route_msg_t));
    	if(rtm == NULL) return FALSE;
    	if (call AMSend.send(address, packet, sizeof(radio_route_msg_t)) == SUCCESS) {
    		locked = TRUE;
        dbg("actual_send", "Packet passed to lower layer successfully!\n");
	     	dbg("actual_send",">>>Packet\n \t Payload length %hhu \n", call Packet.payloadLength(packet));
	     	dbg_clear("actual_send","\t Destination Address: %hu\n", address);
		 	  dbg_clear("actual_send", "\t Type: %hhu (0 = DATA, 1 = ROUTE_REQ, 2 = ROUTE_REPLY)\n", rtm->Type);
		 	  dbg_clear("actual_send","\t Payload Sent\n" );
        return TRUE;
    	}
    	return FALSE;
    }
  }


  event void Boot.booted() {
    dbg("boot","Application booted.\n");

    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
  	if(err == SUCCESS) {
  		dbg("start_done","Node %hu ActiveMessageControl Started!\n",TOS_NODE_ID);
  		locked=FALSE;
    	initRoutingTable();
    	call Timer1.startOneShot(FIRST_VALUE_TIMEOUT);
    } else {
    	call AMControl.start(); // retry
    }
  }

  void initRoutingTable() {
  	uint8_t i;
  	for(i=0; i<MAX_NODES; i++) {
      routing_table[i].Destination = i+1;
      routing_table[i].NextHop = 0;
      routing_table[i].Cost = INFINITY;
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
      radio_route_msg_t* rtm = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
      dbg("t1_fired","Simulation Started\n");
      rtm->Type = DATA;
      rtm->Destination = FIRST_VALUE_DESTINATION;
      rtm->Sender = TOS_NODE_ID;
      rtm->Value = FIRST_VALUE;
      data_msg = *rtm;
      handleData(rtm); // will try to send the data, this will result in a ROUTE_REQ being broadcasted
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
	dbg("receive","Message Received\n");
	dbg_clear("receive","\t Payload Length: %hhu\n",call Packet.payloadLength(bufPtr));
    if(len != sizeof(radio_route_msg_t)) {
    	return bufPtr;
    } else {
    	radio_route_msg_t* rtm = (radio_route_msg_t*) payload;
    	ledUpdate();
    	switch(rtm->Type) {
      		case DATA: handleData(rtm); break;
      		case ROUTE_REQ: handleRouteReq(rtm); break;
      		case ROUTE_REPLY: handleRouteReply(rtm); break;
    	}
    	return bufPtr;
    }
  }

  void ledUpdate() {
    uint8_t led = person_code[led_iter++] % 3;
    switch(led) {
      case 0:
        call Leds.led0Toggle(); break;
      case 1:
        call Leds.led1Toggle(); break;
      case 2:
        call Leds.led2Toggle(); break;
    }
    if(led_iter == 8) led_iter = 0; // at the end return to the first
    if(TOS_NODE_ID == 6) dbg("led_update","Led Update: %hhu%hhu%hhu\n", (call Leds.get() & LEDS_LED0) == 1, (call Leds.get() & LEDS_LED1) == 2, (call Leds.get() & LEDS_LED2) == 4);
  }

  void handleData(radio_route_msg_t* rtm) {
    uint16_t destination = rtm->Destination;
    dbg("handle_data","Handling Data\n");
    dbg_clear("handle_data","\tDestination Address: %hu\n",rtm->Destination);
    dbg_clear("handle_data","\tSender Address: %hu\n",rtm->Sender);
    dbg_clear("handle_data","\tValue: %hu\n",rtm->Value);
    if (isDestinationReachable(destination)) {
      uint16_t nextHop = getNextHop(destination);
      radio_route_msg_t* rtm_tmp = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
      dbg_clear("handle_data","\tHandling Data: Route Found\n");
      dbg_clear("handle_data","\tNext Hop: %hu\n", nextHop);
      rtm_tmp->Type = DATA;
      rtm_tmp->Destination = destination;
      rtm_tmp->Sender = TOS_NODE_ID;
      rtm_tmp->Value = rtm->Value;
      generate_send(nextHop, &packet, DATA);
    } else if(TOS_NODE_ID == 7) {
      dbg_clear("handle_data","\tNode 7 got the packet from Node 1\n");
    }
    else {
      radio_route_msg_t* rtm_tmp = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
      dbg_clear("handle_data","\tHandling Data: Route Not Found -> Broadcasting Route Request\n");
      rtm_tmp->Type = ROUTE_REQ;
      rtm_tmp->NodeRequested = destination;
      generate_send(AM_BROADCAST_ADDR, &packet, ROUTE_REQ);
    }
  }

  void handleRouteReq(radio_route_msg_t* rtm) {
    uint16_t nodeRequested = rtm->NodeRequested;
    dbg("handle_route_req","Handling Route Request\n");
    dbg_clear("handle_route_req","\tNode Requested: %hu \n", nodeRequested);
    if(nodeRequested != TOS_NODE_ID && !isDestinationReachable(nodeRequested)) {
      radio_route_msg_t* rtm_tmp = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
      dbg_clear("handle_route_req","\tHandling Route Request: Route Not Found -> Broadcasting Route Request\n");
      rtm_tmp->Type = rtm->Type;
      rtm_tmp->NodeRequested = rtm->NodeRequested;
      generate_send(AM_BROADCAST_ADDR, &packet, ROUTE_REQ);
    }
    else if(nodeRequested == TOS_NODE_ID) {
      radio_route_msg_t* rtm_tmp = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
      dbg_clear("handle_route_req","\tI'm the requested node\n");
      rtm_tmp->Type = ROUTE_REPLY;
      rtm_tmp->Cost = 1;
      rtm_tmp->NodeRequested = TOS_NODE_ID;
      rtm_tmp->Sender = TOS_NODE_ID;
      generate_send(AM_BROADCAST_ADDR, &packet, ROUTE_REPLY);
    }
    else if(isDestinationReachable(nodeRequested)) {
      radio_route_msg_t* rtm_tmp = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
      dbg_clear("handle_route_req","\tRoute to the requested node found\n");
      rtm_tmp->Type = ROUTE_REPLY;
      rtm_tmp->Cost = getCost(nodeRequested) + 1;
      rtm_tmp->NodeRequested = nodeRequested;
      rtm_tmp->Sender = TOS_NODE_ID;
      generate_send(AM_BROADCAST_ADDR, &packet, ROUTE_REPLY);
    }

  }

  void handleRouteReply(radio_route_msg_t* rtm) {
    uint16_t nodeRequested = rtm->NodeRequested;
    dbg("handle_route_reply","Handling Route Reply\n");

    if(nodeRequested != TOS_NODE_ID && rtm->Cost < getCost(nodeRequested)) { // if the nodeRequested is unreachable, the cost is INFINITY
    	radio_route_msg_t* rtm_tmp = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
    	rtm_tmp->Type = rtm->Type;
    	rtm_tmp->Sender = TOS_NODE_ID;
    	rtm_tmp->NodeRequested = rtm->NodeRequested;
    	rtm_tmp->Cost = rtm_tmp->Cost+1;

    	/* Update Routing Table */
        routing_table[nodeRequested-1].Cost = rtm->Cost;
        routing_table[nodeRequested-1].NextHop = rtm->Sender;

        if(TOS_NODE_ID == FIRST_SENDER && !data_sent) { // Node 1 got its route to destination 7!
        	data_sent = TRUE;
        	dbg("handle_route_reply","Node 1 can now send the packet to destination 7\n");
        	handleData(&data_msg);
    	}
        else {
        	dbg("handle_route_reply","Routing Table Updated: Broadcasting Route Reply\n");
        	generate_send(AM_BROADCAST_ADDR, &packet, ROUTE_REPLY);
        }
    }
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	/* This event is triggered when a message is sent
	*  Check if the packet is sent
	*/
	  if (&queued_packet == bufPtr && error == SUCCESS) {
	    locked = FALSE;
      dbg("actual_send", "Packet sent...\n");
      dbg_clear("actual_send", " at time %s \n", sim_time_string());
    }
    else {
      dbgerror("actual_send", "Send done error!\n");
    }
  }

  uint8_t getCost(uint16_t destination) {
  	uint8_t i;
    for(i=0; i<MAX_NODES; i++) {
      if(routing_table[i].Destination == destination) {
        return routing_table[i].Cost;
      }
    }
  }

  bool isDestinationReachable(uint16_t destination) {
    return getCost(destination) != INFINITY;
  }

  uint16_t getNextHop(uint16_t destination) {
  	uint8_t i;
    for(i=0; i<MAX_NODES; i++) {
      if(routing_table[i].Destination == destination) {
        return routing_table[i].NextHop;
      }
    }
  }
}