#ifndef RADIO_ROUTE_H
#define RADIO_ROUTE_H

#define INFINITY 255
#define MAX_NODES 10

#define FIRST_SENDER 1
#define FIRST_VALUE_TIMEOUT 5000
#define FIRST_VALUE_DESTINATION 7
#define FIRST_VALUE 5

enum {
	DATA, ROUTE_REQ, ROUTE_REPLY
};

typedef nx_struct radio_route_msg {
	nx_uint8_t Type;
	nx_uint16_t Sender;
	nx_uint16_t Destination;
	nx_uint16_t Value;
	nx_uint16_t NodeRequested;
	nx_uint8_t Cost;
} radio_route_msg_t;


enum {
  AM_RADIO_COUNT_MSG = 10,
};

typedef nx_struct routing_table_entry {
	nx_uint16_t Destination;
	nx_uint16_t NextHop;
	nx_uint8_t Cost;
} routing_table_entry_t;

typedef	routing_table_entry_t routing_table_t[MAX_NODES];

#endif