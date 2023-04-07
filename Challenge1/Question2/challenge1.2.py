import json

with open('1.2.1.json') as f:
    data = json.load(f)

    packets = []

    # Filter packets with coap.code > 100.
    for packet in data:
        if int(packet['_source']['layers']['coap']['coap.code']) > 100:
            packets.append(packet)

    tokens = []
    mid = []

    # Filter tokens and mid
    for packet in packets:
        if 'coap.token' in packet['_source']['layers']['coap'] and 'coap.mid' in packet['_source']['layers']['coap']:
            tokens.append(packet['_source']['layers']['coap']['coap.token'])
            mid.append(packet['_source']['layers']['coap']['coap.mid'])

    # Remove duplicates from tokens and mid
    tokens = list(set(tokens))
    mid = list(set(mid))

    print('Tokens and MID of packets with coap.code > 100:')
    print(','.join(tokens))
    print(','.join(mid))

with open('1.2.2.json', 'r') as f1:
    with open('1.2.3.json', 'r') as f2:
        data1 = json.load(f1)
        data2 = json.load(f2)

        frame_numbers1 = []
        frame_numbers2 = []

        # Filter frame numbers
        for packet in data1:
            frame_numbers1.append(
                packet['_source']['layers']['frame']['frame.number'])

        for packet in data2:
            frame_numbers2.append(
                packet['_source']['layers']['frame']['frame.number'])

        # Remove duplicates from frame numbers
        frame_numbers = list(set(frame_numbers1 + frame_numbers2))

        print(len(frame_numbers))

        # print(','.join(frame_numbers))
