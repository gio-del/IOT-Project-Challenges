#include "PubSub.h"

module ClientNodeC {
  uses {
    interface Boot;
    interface Timer<TMilli> as Timer0;
    interface Timer<TMilli> as Timer1;
    interface AMSend;
    interface Receive;
    interface SplitControl;
    interface Random;
  }
}
implementation {

  bool isConnected = FALSE;
  bool isSubscribed = FALSE;
  uint8_t nodeID;
  uint8_t subscribedTopic;
  uint16_t connectCounter;
  uint16_t subscribeCounter;

  enum {
    TIMER_PERIOD_MILLI = 1000,
    CONNECT_RETRIES = 3,
    SUBSCRIBE_RETRIES = 3
  };

  MessageFormat msg; // Message buffer

  event void Boot.booted() {
    nodeID = 0; // this should be assigned by the coordinator?

    subscribedTopic = TEMPERATURE; // this should be random

    sendConnectMsg();
  }

  /* Connection Attempt */
  event void Timer0.fired() {
    if (!isConnected) {
      if (connectCounter < CONNECT_RETRIES) {
        connectCounter++;
        sendConnectMsg();
      } else {
        // Maximum connection retries reached
      }
    }
  }

  /* Subscription Attempt */
  event void Timer1.fired() {
    if (!isSubscribed) {
      if (subscribeCounter < SUBSCRIBE_RETRIES) {
        subscribeCounter++;
        sendSubscribeMsg();
      } else {
        // Maximum subscribe retries reached
      }
    }
  }

  // Helper functions
  void sendConnectMsg() {
    // Prepare CONNECT message
    msg.messageType = CONNECT_MSG;
    msg.nodeID = nodeID;

    // Send CONNECT message
    if (AMSend.send(AM_BROADCAST_ADDR, &msg, sizeof(MessageFormat)) == SUCCESS) {
      // Schedule timer for connection retries
      call Timer0.startOneShot(TIMER_PERIOD_MILLI);
    }
  }

  void sendSubscribeMsg() {
    // Prepare SUBSCRIBE message
    msg.messageType = SUBSCRIBE_MSG;
    msg.nodeID = nodeID;
    msg.topic = subscribedTopic;

    // Send SUBSCRIBE message
    if (AMSend.send(AM_BROADCAST_ADDR, &msg, sizeof(MessageFormat)) == SUCCESS) {
      // Schedule timer for subscribe retries
      call Timer1.startOneShot(TIMER_PERIOD_MILLI);
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
    // Handle received message
    MessageFormat* receivedMsg = (MessageFormat*)payload;

    // Process different message types
    switch (receivedMsg->messageType) {
      case CONNACK_MSG:
        if (receivedMsg->nodeID == nodeID) {
          // Connection acknowledged by the coordinator
          isConnected = TRUE;
          // Subscribe to the topic
          sendSubscribeMsg();
          call Timer1.startOneShot(TIMER_PERIOD_MILLI);
        }
        break;

      case SUBACK_MSG:
        if (receivedMsg->nodeID == nodeID && receivedMsg->topic == subscribedTopic) {
          // Subscription acknowledged by the coordinator
          isSubscribed = TRUE;
        }
        break;

      case PUBLISH_MSG:
        if (isSubscribed && receivedMsg->topic == subscribedTopic) {
          // Handle the received published message
          // You can process the payload or take any other required action
        }
        break;
    }

    return msg;
  }
}