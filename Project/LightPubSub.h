#ifndef LIGHT_PUB_SUB_H
#define LIGHT_PUB_SUB_H

#define MAX_NODES 10
#define MESSAGE_DELAY 100
#define PAN_COORDINATOR_ID 0

enum {
    TEMPERATURE, HUMIDITY, LUMINOSITY
};

enum {
    CONN, CONNACK, SUB, SUBACK, PUB
};

enum {
  AM_RADIO_COUNT_MSG = 6,
};

typedef nx_struct pub_sub_msg {
    nx_uint8_t type;
    nx_uint16_t sender;
    nx_uint8_t topic;
    nx_uint16_t payload;
} pub_sub_msg_t;

typedef nx_struct client_info {
    nx_uint8_t topic;
    bool is_subscribed;
    bool is_connected;
} client_info_t;

typedef client_info_t client_list_t[MAX_NODES];

typedef nx_struct message_list {
    pub_sub_msg_t msg;
    nx_uint16_t destination;
    struct message_list* next;
} message_list_t;

/*Utility functions for the message list*/
void add_message(message_list_t* list, pub_sub_msg_t msg, nx_uint16_t destination);
nx_uint16_t pop_message(message_list_t* list, pub_sub_msg_t* message);
bool is_empty(message_list_t* list);

/*
    * Adds a message to the list
    * The message is added to the end of the list
*/
void add_message(message_list_t* list, pub_sub_msg_t msg, nx_uint16_t destination) {
    message_list_t* new_message = (message_list_t*) malloc(sizeof(message_list_t));
    new_message->msg = msg;
    new_message->destination = destination;
    new_message->next = NULL;

    if (is_empty(list)) {
        *list = new_message;
    } else {
        message_list_t* current = list;
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
nx_uint16_t pop_message(message_list_t* list, pub_sub_msg_t* message) {
    if (is_empty(list)) {
        return 0;
    } else {
        message_list_t* current = list;
        message_list_t* previous = NULL;
        while (current->next != NULL) {
            previous = current;
            current = current->next;
        }
        previous->next = NULL;
        *message = current->msg;
        return current->destination;
    }
}

/*
    * Checks if the list is empty
*/
bool is_empty(message_list_t* list) {
    return list == NULL;
}

#endif