import json

with open('1.3.json') as f:
    data = json.load(f)
    # Filter out the packets with uri-path that doesn't contain a + sign
    filtered_items = [item for item in data if 'mqtt' in item['_source']['layers'] and 'mqtt.topic' in item['_source']
                      ['layers']['mqtt'] and '+' in item['_source']['layers']['mqtt']['mqtt.topic']]
    print(len(filtered_items))
    for item in filtered_items:
        print(item['_source']['layers']['mqtt']['mqtt.topic'],
              item['_source']['layers']['frame']['frame.number'])
    numbers = [int(item['_source']['layers']['frame']['frame.number'])
               for item in filtered_items]
    # join the numbers with a comma
    print(','.join(str(n) for n in numbers))

    # Count how many different source ports there are and print them
    source_ports = [item['_source']['layers']['tcp']['tcp.srcport']
                    for item in filtered_items]
    print(len(set(source_ports)))
    print(set(source_ports))
