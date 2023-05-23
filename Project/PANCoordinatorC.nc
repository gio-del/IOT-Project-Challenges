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
  PublishedMessage publishedMessages[MAX_PUBLISHED_MESSAGES];

  enum {
    TIMER_PERIOD_MILLI = 1000,
    CONNACK_RETRIES = 3
  };

  MessageFormat msg; // Message buffer

  event void Boot.booted() {
    for (uint8_t i = 0; i < MAX_CLIENT_NODES; i++) {
      clientNodes[i].isConnected = FALSE;
      clientNodes[i].nodeID = 0;
      clientNodes[i].subscribedTopic = NO_TOPIC;
    }

    for (uint8_t i = 0; i < MAX_PUBLISHED_MESSAGES; i++) {
      publishedMessages[i].isPublished = FALSE;
      publishedMessages[i].topic = NO_TOPIC;
      publishedMessages[i].payload = 0;
    }
  }

  // TODO: check this, shouldn't be the coordinator to resend the CONNACK message.
  /*Timer for sending CONNACK messages*/
  event void Timer0.fired() {
    for (uint8_t i = 0; i < MAX_CLIENT_NODES; i++) {
      if (clientNodes[i].isConnected && !clientNodes[i].nodeID) {
        sendConnackMsg(clientNodes[i].nodeID);
      }
    }
  }

  /*Timer for publishing messages*/
  event void Timer1.fired() {
    for (uint8_t i = 0; i < MAX_PUBLISHED_MESSAGES; i++) {
      if (publishedMessages[i].isPublished) {
        forwardPublishedMsg(publishedMessages[i]);
      }
    }
    // TODO: should we clear the published messages?
  }


  // Helper functions
  void sendConnackMsg(uint8_t nodeID) {

    msg.messageType = CONNACK_MSG;
    msg.nodeID = nodeID;

    if (AMSend.send(nodeID, &msg, sizeof(MessageFormat)) == SUCCESS) {
      call Timer0.startOneShot(TIMER_PERIOD_MILLI);
    }
  }

  void forwardPublishedMsg(PublishedMessage publishedMsg) {
    msg.messageType = PUBLISH_MSG;
    msg.topic = publishedMsg.topic;
    msg.payload = publishedMsg.payload;

    for (uint8_t i = 0; i < MAX_CLIENT_NODES; i++) {
      if (clientNodes[i].subscribedTopic == publishedMsg.topic) {
        AMSend(i, &msg, sizeof(MessageFormat)); // TODO: check if this is correct, also for SUCCESS
      }
    }
  }

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
        handleConnection();
        break;

      case SUBSCRIBE_MSG:
        handleSubscribe();
        break;

      case PUBLISH_MSG:
        handlePublish();
        break;
    }
    return msg;
  }

  void handleConnection() {
    if (!clientNodes[receivedMsg->nodeID].isConnected) {

          clientNodes[receivedMsg->nodeID].isConnected = TRUE;
          clientNodes[receivedMsg->nodeID].nodeID = receivedMsg->nodeID;

          sendConnackMsg(receivedMsg->nodeID);
        }
  }

  void handleSubscribe() {
    clientNodes[receivedMsg->nodeID].subscribedTopic = receivedMsg->topic;
  }

  void handlePublish() {
    for (uint8_t i = 0; i < MAX_PUBLISHED_MESSAGES; i++) {
      if (!publishedMessages[i].isPublished) {
        publishedMessages[i].isPublished = TRUE;
        publishedMessages[i].topic = receivedMsg->topic;
        publishedMessages[i].payload = receivedMsg->payload;
        break;
      }
    }
    Timer1.startOneShot(TIMER_PERIOD_MILLI);
  }
}
