import json

with open('1.5.1.json') as f:
    data = json.load(f)

    tot_mqtt = 0
    tot_qos1 = 0

    for i in data:
        if 'ismqttarray' in i:
            for j in i['_source']['layers']['mqtt']:
                tot_mqtt += 1
                if j['mqtt.hdrflags_tree']['mqtt.qos'] == '1':
                    tot_qos1 += 1
        else:
            tot_mqtt += 1
            if i['_source']['layers']['mqtt']['mqtt.hdrflags_tree']['mqtt.qos'] == '1':
                tot_qos1 += 1

    print('Total MQTT packets: {}'.format(tot_mqtt))
    print('Total MQTT QoS 1 packets: {}'.format(tot_qos1))
