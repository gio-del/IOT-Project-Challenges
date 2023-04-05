import json

# Open the file
with open('1.1.json', 'r') as f:
    # Load the JSON
    data = json.load(f)
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

with open('1.1.2.json', 'r') as f:
    data = json.load(f)
    unique_mid = []
    unique_tokens = []
    for item in data:
        if 'coap' in item['_source']['layers']:
            if item['_source']['layers']['coap']['coap.mid'] not in unique_mid:
                unique_mid.append(
                    item['_source']['layers']['coap']['coap.mid'])
            if 'coap.token' in item['_source']['layers']['coap'] and item['_source']['layers']['coap']['coap.token'] not in unique_tokens:
                unique_tokens.append(
                    item['_source']['layers']['coap']['coap.token'])

    print(', '.join(unique_mid))
    print(', '.join(unique_tokens))
