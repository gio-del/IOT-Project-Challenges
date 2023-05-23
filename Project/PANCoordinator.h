#ifndef PAN_COORDINATOR_H
#define PAN_COORDINATOR_H

#include "PubSub.h"

// Maximum number of connected client nodes and published messages
#define MAX_CLIENT_NODES 8
#define MAX_PUBLISHED_MESSAGES 100

// Structure to store information about connected client nodes
typedef struct {
  bool isConnected;
  uint8_t nodeID;
  uint8_t subscribedTopic;
} ClientNodeInfo;

// Structure to store published messages
typedef struct {
  bool isPublished;
  Topic topic;
  uint8_t payload;
} PublishedMessage;

#endif // PAN_COORDINATOR_H