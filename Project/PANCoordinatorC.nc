#include "PANCoordinator.h"

module PANCoordinatorC {
  uses {
    interface Boot;
    interface Timer<TMilli> as Timer0;
    interface Timer<TMilli> as Timer1;
    interface AMSend;
    interface Receive;
    interface SplitControl;
  }
}
implementation {

  ClientNodeInfo clientNodes[MAX_CLIENT_NODES];
  PublishedMessage publishedMessages[MAX_TOPICS];

  enum {
    TIMER_PERIOD_MILLI = 1000,
    CONNACK_RETRIES = 3
  };

  MessageFormat msg;


  event void Boot.booted() {
    for (uint8_t i = 0; i < MAX_CLIENT_NODES; i++) {
      clientNodes[i].isConnected = FALSE;
      clientNodes[i].nodeID = 0;
      clientNodes[i].subscribedTopic = NO_TOPIC;
    }

    for (uint8_t i = 0; i < MAX_TOPICS; i++) {
      publishedMessages[i].isPublished = FALSE;
      publishedMessages[i].topic = i;
      publishedMessages[i].payload = 0;
    }
  }

  event void Timer0.fired() {
    for (uint8_t i = 0; i < MAX_CLIENT_NODES; i++) {
      if (clientNodes[i].isConnected && !clientNodes[i].nodeID) {
        sendConnackMsg(clientNodes[i].nodeID);
      }
    }
  }

  event void Timer1.fired() {
    for (uint8_t i = 0; i < MAX_TOPICS; i++) {
      if (publishedMessages[i].isPublished) {
        forwardPublishedMsg(i, publishedMessages[i].payload);
      }
    }
  }


  // Helper functions
  void sendConnackMsg(uint8_t nodeID) {

    msg.messageType = CONNACK_MSG;
    msg.nodeID = nodeID;

    if (AMSend.send(nodeID, &msg, sizeof(MessageFormat)) == SUCCESS) {
      call Timer0.startOneShot(TIMER_PERIOD_MILLI);
    }
  }

  void forwardPublishedMsg(uint8_t topic, uint8_t payload) {
    msg.messageType = PUBLISH_MSG;
    msg.topic = topic;
    msg.payload = payload;

    for (uint8_t i = 0; i < MAX_CLIENT_NODES; i++) {
      if (clientNodes[i].isConnected && clientNodes[i].subscribedTopic == topic) {
        AMSend.send(clientNodes[i].nodeID, &msg, sizeof(MessageFormat));
      }
    }
  }

  // Implementation-specific event handlers
  event void AMSend.sendDone(message_t* msg, error_t error) {
    // Handle send completion
    if (error == SUCCESS) {
      // Message sent successfully
    } else {
      // Error in sending message
    }
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    MessageFormat* receivedMsg = (MessageFormat*)payload;

    switch (receivedMsg->messageType) {
      case CONNECT_MSG:
        if (!clientNodes[receivedMsg->nodeID].isConnected) {

          clientNodes[receivedMsg->nodeID].isConnected = TRUE;
          clientNodes[receivedMsg->nodeID].nodeID = receivedMsg->nodeID;

          sendConnackMsg(receivedMsg->nodeID);
        }
        break;

      case SUBSCRIBE_MSG:
        clientNodes[receivedMsg->nodeID].subscribedTopic = receivedMsg->topic;
        break;

      case PUBLISH_MSG:
        forwardPublishedMsg(receivedMsg->topic, receivedMsg->payload);
        break;
    }
    return msg;
  }
}
