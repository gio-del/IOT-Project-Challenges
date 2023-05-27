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
 	interface Leds;
 	//other interfaces, if needed
  }
}
implementation {
    message_t packet;
    client_list_t client_list;
    bool locked;

    /*PROTOTYPES*/
    void initClientList();
    void handleConnect(pub_sub_msg_t* msg);
    void handleConnectAck(pub_sub_msg_t* msg);
    void handleSubscribe(pub_sub_msg_t* msg);
    void handleSubscribeAck(pub_sub_msg_t* msg);
    void handlePublish(pub_sub_msg_t* msg);


    event void Boot.booted() {
        call AMControl.start();
    }

    event void AMControl.startDone(error_t err) {
        if (err == SUCCESS) {
            if(TOS_NODE_ID == PAN_COORDINATOR_ID) {
                initClientList();
            }
        } else {
            call AMControl.start(); // try again
        }
    }

    event void AMControl.stopDone(error_t err) {}

    void initClientList() {
        uint8_t i;
        for(i = 0; i < MAX_NODES; i++) {
            client_list[i].node_id = i+1;
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
        }
    }

    void handleConnect(pub_sub_msg_t* msg) {
        if(msg->node_id == PAN_COORDINATOR_ID) {
            return;
        }
        if(client_list[msg->node_id-1].is_connected == TRUE) {
            return;
        }
        client_list[msg->node_id-1].is_connected = TRUE;
        packet.type = CONNACK;
        packet.node_id = TOS_NODE_ID;
        packet.data = msg->data;
        call AMSend.send(msg->node_id, &packet, sizeof(pub_sub_msg_t));
    }

    void handleConnectAck(pub_sub_msg_t* msg) {
        if(msg->node_id == PAN_COORDINATOR_ID) {
            return;
        }
        if(client_list[msg->node_id-1].is_connected == TRUE) {
            return;
        }
        client_list[msg->node_id-1].is_connected = TRUE;
    }

    void handleSubscribe(pub_sub_msg_t* msg) {
        if(msg->node_id == PAN_COORDINATOR_ID) {
            return;
        }
        if(client_list[msg->node_id-1].is_subscribed == TRUE) {
            return;
        }
        client_list[msg->node_id-1].is_subscribed = TRUE;
        packet.type = SUBACK;
        packet.node_id = TOS_NODE_ID;
        packet.data = msg->data;
        call AMSend.send(msg->node_id, &packet, sizeof(pub_sub_msg_t));
    }

    void handleSubscribeAck(pub_sub_msg_t* msg) {
        if(msg->node_id == PAN_COORDINATOR_ID) {
            return;
        }
        if(client_list[msg->node_id-1].is_subscribed == TRUE) {
            return;
        }
        client_list[msg->node_id-1].is_subscribed = TRUE;
    }

    void handlePublish(pub_sub_msg_t* msg) {
        if(msg->node_id == PAN_COORDINATOR_ID) {
            return;
        }
        if(client_list[msg->node_id-1].is_subscribed == FALSE) {
            return;
        }
        packet.type = PUB;
        packet.node_id = TOS_NODE_ID;
        packet.data = msg->data;
        call AMSend.send(msg->node_id, &packet, sizeof(pub_sub_msg_t));
    }
}