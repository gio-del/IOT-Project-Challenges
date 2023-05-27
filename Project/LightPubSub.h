#ifndef LIGHT_PUB_SUB_H
#define LIGHT_PUB_SUB_H

#define MAX_NODES 10
#define PAN_COORDINATOR_ID 0

enum {
    TEMPERATURE, HUMIDITY, LUMINOSITY
};

enum {
    CONN, CONNACK, SUB, SUBACK, PUB
}

enum {
  AM_RADIO_COUNT_MSG = 6,
};

typedef nx_struct pub_sub_msg {
    nx_uint8_t type;
    nx_uint16_t sender;
    nx_uint16_t topic;
    nx_uint16_t payload;
} pub_sub_msg_t;

typedef nx_struct client_info {
    nx_uint16_t node_id;
    nx_uint16_t topic;
    bool is_subscribed;
    bool is_connected;
} client_info_t;

typedef client_info_t client_list_t[MAX_NODES];

#endif