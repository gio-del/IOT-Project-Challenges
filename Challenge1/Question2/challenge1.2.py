import json

# Open the file
with open('1.2.1.json', 'r') as f:
    # Load the JSON
    data = json.load(f)
    print('1.2.1', len(data))
    unique_mid = []
    unique_tokens = []
    # Loop through the data
    for item in data:
        # filter packet that contains layer CoAP
        if 'coap' in item['_source']['layers']:
            # Filter by unique message ID
            if item['_source']['layers']['coap']['coap.mid'] not in unique_mid:
                unique_mid.append(
                    item['_source']['layers']['coap']['coap.mid'])

            # Filter by unique token
            if 'coap.token' in item['_source']['layers']['coap'] and item['_source']['layers']['coap']['coap.token'] not in unique_tokens:

                unique_tokens.append(
                    item['_source']['layers']['coap']['coap.token'])

    # Print as spaced list of numbers
    print(', '.join(unique_mid))
    print(', '.join(unique_tokens))

# Open 1.2.2.json and 1.2.3.json and remove the overlapping packets
packets = []
with open('1.2.2.json', 'r') as f1:
    with open('1.2.3.json', 'r') as f2:
        # remove the overlapping packets
        data1 = json.load(f1)
        data2 = json.load(f2)
        print('1.2.2', len(data1))
        print('1.2.3', len(data2))
        frame_numbers1 = []
        frame_numbers2 = []
        for item in data1:
            frame_numbers1.append(
                item['_source']['layers']['frame']['frame.number'])

        for item in data2:
            frame_numbers2.append(
                item['_source']['layers']['frame']['frame.number'])

        # join the two lists removing the overlapping packets
        frame_numbers = list(set(frame_numbers1 + frame_numbers2))
        frame_numbers.sort()
        print(frame_numbers)
        print(len(frame_numbers))
        print(frame_numbers1)
        print(len(frame_numbers1))
        print(frame_numbers2)
        print(len(frame_numbers2))
