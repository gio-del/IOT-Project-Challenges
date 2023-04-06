import json

with open('1.5.json') as f:
    data = json.load(f)

    # Extract the tcp src ports

    tcp_src_ports = []
    for i in data:
        tcp_src_ports.append(i['_source']['layers']['tcp']['tcp.srcport'])

    # Join the list into a string
    print(','.join(tcp_src_ports))
