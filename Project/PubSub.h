#ifndef PUBSUB_H
#define PUBSUB_H

// Message types
#define CONNECT_MSG 0
#define CONNACK_MSG 1
#define SUBSCRIBE_MSG 2
#define SUBACK_MSG 3
#define PUBLISH_MSG 4

// Maximum payload size
#define MAX_PAYLOAD_SIZE 128

// Message structure
typedef nx_struct MessageFormat {
  nx_uint8_t messageType;
  nx_uint8_t nodeID;
  nx_uint8_t topic;
  nx_uint8_t payload[MAX_PAYLOAD_SIZE];
} MessageFormat;

// Topic enum
enum {
  TEMPERATURE = 0,
  HUMIDITY = 1,
  LUMINOSITY = 2
};

#endif // PUBSUB_H
