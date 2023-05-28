#include "Timer.h"
#include "LightPubSub.h"

module LightPubSubC @safe() {
  uses {

    /****** INTERFACES *****/
	interface Boot;

  	interface SplitControl as AMControl;
  	interface Receive;
  	interface AMSend;
 	interface Packet;
 	interface Timer<TMilli> as Timer0;
 	interface Timer<TMilli> as Timer1;
    interface Timer<TMilli> as Timer2;
 	interface Leds;
 	//other interfaces, if needed
  }
}
implementation {
    /*Shared Variables*/
    message_t packet;

    message_t queued_packet;
    uint16_t queued_address;
    bool locked;

    /*Client Variables*/
    bool connectAcked;
    bool subscribeAcked;

    /*PAN Coordinator Variables*/
    
	typedef struct message_list {
    	pub_sub_msg_t msg;
    	uint16_t destination;
    	struct message_list* next;
	} message_list_t;

	/*Utility functions for the message list*/
	void add_message(message_list_t** list, pub_sub_msg_t msg, uint16_t destination);
	uint16_t pop_message(message_list_t** list, pub_sub_msg_t* message);
	bool is_empty_message_list(message_list_t** list);

    client_list_t client_list;
    message_list_t* message_list = NULL;

    /*PROTOTYPES*/
    bool generate_send(uint16_t address, message_t* msg);
    bool actual_send(uint16_t address, message_t* msg);
    void initClientList();

    void handleConnect(pub_sub_msg_t* msg);
    void handleConnectAck(pub_sub_msg_t* msg);
    void handleSubscribe(pub_sub_msg_t* msg);
    void handleSubscribeAck(pub_sub_msg_t* msg);
    void handlePublish(pub_sub_msg_t* msg);
    void addClientMatchingTopic(client_list_t client_list, pub_sub_msg_t msg);

    /*IMPLEMENTATIONS*/
    bool generate_send(uint16_t address, message_t* msg) {
        if(call Timer0.isRunning() == TRUE) {
            return FALSE;
        }
        queued_packet = *msg;
        queued_address = address;
        call Timer0.startOneShot(MESSAGE_DELAY);
        return TRUE;
    }

    event void Timer0.fired() {
        actual_send(queued_address, &queued_packet);
    }

    /*
        * This timer is used to send message to the clients. It will use the message list
    */
    event void Timer1.fired() {
        if(is_empty_message_list(&message_list) == TRUE) {
            return;
        } else {
        	pub_sub_msg_t msg;
        	uint16_t destination = pop_message(&message_list, &msg);
        	pub_sub_msg_t* payload = (pub_sub_msg_t*) call Packet.getPayload(&packet, sizeof(pub_sub_msg_t));
        	dbg("t1_fired", "PAN Coordinator has a message to send\n");
        	*payload = msg;
        	generate_send(destination, &packet);
        }
    }

    /*
        * This timer is used to send a connection request to the PAN Coordinator and then subscribe to a random topic
    */
    event void Timer2.fired() {
        if(TOS_NODE_ID == PAN_COORDINATOR_ID) {
            return;
        }
        if(connectAcked == TRUE) {
            dbg("t2_fired", "Client is already connected, sending a subscription request\n");
            // TODO: subscription to a random topic then handle subscription ack
            return;
        } else {
        	pub_sub_msg_t* msg = (pub_sub_msg_t*) call Packet.getPayload(&packet, sizeof(pub_sub_msg_t));
        	dbg("t2_fired", "Client is not connected, sending a connection request\n");    
        	msg->type = CONN;
        	msg->sender = TOS_NODE_ID;
        	generate_send(PAN_COORDINATOR_ID, &packet);
        	call Timer2.startOneShot(2000);
        }
    }

    bool actual_send(uint16_t address, message_t* msg) {
        dbg("actual_send", "Sending message\n");
        if(locked == TRUE) {
            dbg_clear("actual_send", "\tLocked\n");
            return FALSE;
        }
        else {
            pub_sub_msg_t* psm = (pub_sub_msg_t*) call Packet.getPayload(msg, sizeof(pub_sub_msg_t));
            if(call AMSend.send(address, msg, sizeof(pub_sub_msg_t)) == SUCCESS) {
                dbg("actual_send", "Packet passed to lower layer successfully!\n");
	     	    dbg("actual_send",">>>Packet\n \t Payload length %hhu \n", call Packet.payloadLength(msg));
	     	    dbg_clear("actual_send","\t Destination Address: %hu\n", address);
		 	    dbg_clear("actual_send", "\t Type: %hhu (0 = CONN, 1 = CONNACK, 2 = SUB, 3 = SUBACK, 4 = PUB)\n", psm->type);
		 	    dbg_clear("actual_send","\t Payload Sent\n" );
                locked = TRUE;
                return TRUE;
            }
        }
        return FALSE;
    }

    event void Boot.booted() {
        call AMControl.start();
    }

    event void AMControl.startDone(error_t err) {
        if (err == SUCCESS) {
            locked = FALSE;
            if(TOS_NODE_ID == PAN_COORDINATOR_ID) {
            	dbg("start_done","PAN Coordinator ActiveMessageControl Started!\n",TOS_NODE_ID);
                initClientList();
                call Timer1.startPeriodic(MESSAGE_DELAY);
            }
            else {
            	dbg("start_done","Node %hu ActiveMessageControl Started!\n",TOS_NODE_ID);
                connectAcked = FALSE;
                subscribeAcked = FALSE;
                call Timer2.startOneShot(2000);
            }
        } else {
            call AMControl.start(); // try again
        }
    }

    event void AMControl.stopDone(error_t err) {}

    event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	    if (&queued_packet == bufPtr && error == SUCCESS) {
	        locked = FALSE;
            dbg("actual_send", "Packet sent...\n");
            dbg_clear("actual_send", " at time %s \n", sim_time_string());
        }
        else {
            dbgerror("actual_send", "Send done error!\n");
        }
    }

    void initClientList() {
        uint8_t i;
        for(i = 0; i < MAX_NODES; i++) {
            client_list[i].topic = -1;
            client_list[i].is_subscribed = FALSE;
            client_list[i].is_connected = FALSE;
        }
    }

    event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
        if(len != sizeof(pub_sub_msg_t)) {
            return bufPtr;
        } else {
            pub_sub_msg_t* msg = (pub_sub_msg_t*) payload;
            switch (msg->type) {
                case CONN: handleConnect(msg); break;
                case CONNACK: handleConnectAck(msg); break;
                case SUB: handleSubscribe(msg); break;
                case SUBACK: handleSubscribeAck(msg); break;
                case PUB: handlePublish(msg); break;
            }
            return bufPtr;
        }
    }

    void handleConnect(pub_sub_msg_t* msg) {
        if(TOS_NODE_ID != PAN_COORDINATOR_ID) { // only the PAN Coordinator can receive connections
            return;
        } else {
        	pub_sub_msg_t* ack = (pub_sub_msg_t*) call Packet.getPayload(&packet, sizeof(pub_sub_msg_t));
        	dbg("handle_connect", "Received connection request from client %hu, sending connection ack\n", msg->sender);
        	client_list[msg->sender-1].is_connected = TRUE;
        	ack->type = CONNACK;
        	add_message(&message_list, *ack, msg->sender);
        }
    }

    void handleConnectAck(pub_sub_msg_t* msg) {
        if(TOS_NODE_ID == PAN_COORDINATOR_ID) { // only clients can receive connection acks
            return;
        }
        dbg("handle_connack", "Received connection ack from PAN Coordinator\n");
        connectAcked = TRUE; // TODO: this must be reset to FALSE each time a new connection is attempted
    }

    void handleSubscribe(pub_sub_msg_t* msg) {
        if(TOS_NODE_ID != PAN_COORDINATOR_ID) { // only the PAN Coordinator can receive subscriptions
            return;
        }
        dbg("handle_subscribe", "Received subscription request from client %hu\n, on topic %hhu\n", msg->sender, msg->topic);
        if(client_list[msg->sender-1].is_connected == FALSE) {
            dbg_clear("handle_subscribe", "\tClient is not connected, ignoring subscription request\n");
            return; // client is not connected then the subscription is invalid
        } else {
        	pub_sub_msg_t* ack = (pub_sub_msg_t*) call Packet.getPayload(&packet, sizeof(pub_sub_msg_t));
        	dbg_clear("handle_subscribe", "\tClient is connected, sending subscription ack\n");
        	client_list[msg->sender-1].is_subscribed = TRUE;
        	client_list[msg->sender-1].topic = msg->topic;
        	ack->type = SUBACK;
        	add_message(&message_list, *ack, msg->sender);
        }
    }

    void handleSubscribeAck(pub_sub_msg_t* msg) {
        if(TOS_NODE_ID == PAN_COORDINATOR_ID) { // only clients can receive subscription acks
            return;
        }
        dbg("handle_suback", "Received subscription ack from PAN Coordinator\n");
        subscribeAcked = TRUE; // TODO: this must be reset to FALSE each time a new subscription is attempted
    }

    void handlePublish(pub_sub_msg_t* msg) {
        if(TOS_NODE_ID == PAN_COORDINATOR_ID) {
            dbg("handle_publish", "Received publish request from client %hu\n, on topic %hhu\n with payload %hu\n", msg->sender, msg->topic, msg->payload);
            dbg_clear("handle_publish", "\tAdding messages for clients subscribed to topic %hhu\n", msg->topic);
            addClientMatchingTopic(client_list, *msg);
        } else {
            dbg("handle_publish", "Received publish request from PAN Coordinator on topic %hhu\n with payload %hu\n", msg->topic, msg->payload);
            // TODO: ??
        }
    }

    void addClientMatchingTopic(client_list_t client_list, pub_sub_msg_t msg) {
        uint8_t i;
        for(i = 0; i < MAX_NODES; i++) {
            if(client_list[i].is_subscribed == TRUE && client_list[i].topic == msg.topic) {
                pub_sub_msg_t* payload = (pub_sub_msg_t*) call Packet.getPayload(&packet, sizeof(pub_sub_msg_t));
                *payload = msg;
                add_message(&message_list, *payload, i+1);
            }
        }
    }
    
    
	/*
   	 	* Adds a message to the list
   		 * The message is added to the end of the list
	*/
	void add_message(message_list_t** list, pub_sub_msg_t msg, uint16_t destination) {
  	  message_list_t* new_message = (message_list_t*) malloc(sizeof(message_list_t));
  	  new_message->msg = msg;
  	  new_message->destination = destination;
  	  new_message->next = NULL;

   	  if (is_empty_message_list(list)) {
      	*list = new_message;
      } else {
        message_list_t* current = *list;
        while (current->next != NULL) {
            current = current->next;
        }
        current->next = new_message;
    }
}

	/*
    	* Pops the last message from the list
    	* Assigns the message to the message pointer
    	* Returns the destination of the message
	*/
	uint16_t pop_message(message_list_t** list, pub_sub_msg_t* message) {
    	if (is_empty_message_list(list)) {
        	return 0;
    	} else {
        	message_list_t* current = *list;
        	message_list_t* previous = NULL;
        	while (current->next != NULL) {
            	previous = current;
            	current = current->next;
        	}
        	if(previous != NULL) {
        		previous->next = NULL;
        	} else {
        		*list = NULL; // TODO: check this line
        	}
        	*message = current->msg;
        	return current->destination;
    	}
	}

	/*
    	* Checks if the list is empty
	*/
	bool is_empty_message_list(message_list_t** list) {
    	return *list == NULL;
	}
}