#include "Timer.h"
#include "LightPubSub.h"
#include "printf.h"

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
    interface Timer<TMilli> as Timer3;
 	interface Leds;
 	interface Random;
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

    client_list_t client_list;
    message_list_t* message_list = NULL;

	/*Utility functions for the message list*/
	void add_message(message_list_t** list, pub_sub_msg_t msg, uint16_t destination);
	uint16_t pop_message(message_list_t** list, pub_sub_msg_t* message);
	bool is_empty_message_list(message_list_t** list);

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
        	call Timer1.startOneShot(MESSAGE_DELAY);
            return;
        } else {
        	pub_sub_msg_t msg;
        	uint16_t destination = pop_message(&message_list, &msg);
        	pub_sub_msg_t* payload = (pub_sub_msg_t*) call Packet.getPayload(&packet, sizeof(pub_sub_msg_t));
        	printf("PAN Coordinator has a message to send\n");
        	*payload = msg;
        	generate_send(destination, &packet);
        	call Timer1.startOneShot(3*MESSAGE_DELAY); // if there is a message to send wait longer to send the next one
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
            printf("Node %d is already connected, sending a subscription request\n", TOS_NODE_ID);
            call Timer3.startOneShot(NODE_DELAY);
            return;
        } else {
        	pub_sub_msg_t* msg = (pub_sub_msg_t*) call Packet.getPayload(&packet, sizeof(pub_sub_msg_t));
        	printf("Node %d is not connected, sending a connection request\n", TOS_NODE_ID);
        	msg->type = CONN;
        	msg->sender = TOS_NODE_ID;
        	generate_send(PAN_COORDINATOR_ID, &packet);
        	call Timer2.startOneShot(NODE_DELAY);
        }
    }

    /*
        * This timer is used to send a subscription request to the PAN Coordinator and handle retranmission
    */
    event void Timer3.fired() {
        if(TOS_NODE_ID == PAN_COORDINATOR_ID) {
            return;
        }
        if(subscribeAcked == TRUE) {
            printf("Node %d is already subscribed, waiting for messages\n", TOS_NODE_ID);
            if(TOS_NODE_ID == 2) {
                // Send a PUB message
                pub_sub_msg_t* msg = (pub_sub_msg_t*) call Packet.getPayload(&packet, sizeof(pub_sub_msg_t));
                msg->type = PUB;
                msg->sender = TOS_NODE_ID;
                msg->topic = call Random.rand16() % NUM_TOPIC;
                msg->payload = call Random.rand16() % MAX_PAYLOAD;
                generate_send(PAN_COORDINATOR_ID, &packet);
            }
            return;
        } else {
        	pub_sub_msg_t* msg = (pub_sub_msg_t*) call Packet.getPayload(&packet, sizeof(pub_sub_msg_t));
        	printf("Node %d is not subscribed, sending a subscription request\n", TOS_NODE_ID);
        	msg->type = SUB;
        	msg->sender = TOS_NODE_ID;
        	msg->topic = call Random.rand16() % NUM_TOPIC;
        	generate_send(PAN_COORDINATOR_ID, &packet);
        	call Timer3.startOneShot(NODE_DELAY);
        }
    }

    bool actual_send(uint16_t address, message_t* msg) {
        if(locked == TRUE) {
            printf("Sending Message: Locked\n");
            return FALSE;
        }
        else {
            pub_sub_msg_t* psm = (pub_sub_msg_t*) call Packet.getPayload(msg, sizeof(pub_sub_msg_t));
            if(call AMSend.send(address, msg, sizeof(pub_sub_msg_t)) == SUCCESS) {
                printf("Packet passed to lower layer");
	     	    printf(" -Dest: %d", address);
		 	    printf(" -Type: %d (0 = CONN, 1 = CONNACK, 2 = SUB, 3 = SUBACK, 4 = PUB)\n", psm->type);
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
            	printf("PAN Coordinator ActiveMessageControl Started!\n",TOS_NODE_ID);
                initClientList();
                call Timer1.startOneShot(MESSAGE_DELAY);
            }
            else {
            	printf("Node %d ActiveMessageControl Started!\n",TOS_NODE_ID);
                connectAcked = FALSE;
                subscribeAcked = FALSE;
                call Timer2.startOneShot(NODE_DELAY);
            }
        } else {
            call AMControl.start(); // try again
        }
    }

    event void AMControl.stopDone(error_t err) {}

    event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	    if (&queued_packet == bufPtr && error == SUCCESS) {
	        locked = FALSE;
        }
        else {
            printf("Send done error!\n");
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
        	printf("Received connection request from client %d, sending connection ack\n", msg->sender);
        	client_list[msg->sender-1].is_connected = TRUE;
        	ack->type = CONNACK;
        	add_message(&message_list, *ack, msg->sender);
        }
    }

    void handleConnectAck(pub_sub_msg_t* msg) {
        if(TOS_NODE_ID == PAN_COORDINATOR_ID) { // only clients can receive connection acks
            return;
        }
        printf("Received connection ack from PAN Coordinator\n");
        connectAcked = TRUE; // TODO: this must be reset to FALSE each time a new connection is attempted
    }

    void handleSubscribe(pub_sub_msg_t* msg) {
        if(TOS_NODE_ID != PAN_COORDINATOR_ID) { // only the PAN Coordinator can receive subscriptions
            return;
        }
        printf("Received subscription request from client %d, on topic %d\n", msg->sender, msg->topic);
        if(client_list[msg->sender-1].is_connected == FALSE) {
            printf(" Client is not connected, ignoring subscription request\n");
            return; // client is not connected then the subscription is invalid
        } else {
        	pub_sub_msg_t* ack = (pub_sub_msg_t*) call Packet.getPayload(&packet, sizeof(pub_sub_msg_t));
        	printf(" Client is connected, sending subscription ack\n");
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
        printf("Received subscription ack from PAN Coordinator\n");
        subscribeAcked = TRUE; // TODO: this must be reset to FALSE each time a new subscription is attempted
    }

    void handlePublish(pub_sub_msg_t* msg) {
        if(TOS_NODE_ID == PAN_COORDINATOR_ID) {
            printf("Received publish request from client %d, on topic %d with payload %d\n", msg->sender, msg->topic, msg->payload);
            printf(" Adding messages for clients subscribed to topic %d\n", msg->topic);
            addClientMatchingTopic(client_list, *msg);
        } else {
            printf("Received publish from PAN Coordinator on topic %d with payload %d\n", msg->topic, msg->payload);
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
    	* Pops the first message from the list
    	* Assigns the message to the message pointer
    	* Returns the destination of the message
	*/
	uint16_t pop_message(message_list_t** list, pub_sub_msg_t* message) {
        if(is_empty_message_list(list)) {
            return 0;
        } else {
            message_list_t* current = *list;
            uint16_t destination = current->destination;
            *message = current->msg;
            *list = current->next;
            free(current);
            return destination;
        }
	}

	/*
    	* Checks if the list is empty
	*/
	bool is_empty_message_list(message_list_t** list) {
    	return *list == NULL;
	}
}
