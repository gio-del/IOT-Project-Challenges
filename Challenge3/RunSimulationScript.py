from TOSSIM import *
import time
import sys
print("********************************************")

print("*                                          *")

print("*             TOSSIM Script                *")

print("*                                          *")

print("********************************************")


t = Tossim([])


t = Tossim([])


topofile = "topology.txt"

modelfile = "meyer-heavy.txt"


print("Initializing mac....")

mac = t.mac()

print("Initializing radio channels....")

radio = t.radio()

print("    using topology file:", topofile)

print("    using noise file:", modelfile)

print("Initializing simulator....")

t.init()


out = sys.stdout


# Add debug channel

print("Activate debug message on channel boot")

t.addChannel("boot", out)

print("Activate debug message on channel actual_send")

t.addChannel("actual_send", out)

print("Activate debug message on channel start_done")

t.addChannel("start_done", out)

print("Activate debug message on channel t1_fired")

t.addChannel("t1_fired", out)

print("Activate debug message on channel receive")

t.addChannel("receive", out)

print("Activate debug message on channel led_update")

t.addChannel("led_update", out)

print("Activate debug message on channel handle_data")

t.addChannel("handle_data", out)

print("Activate debug message on channel handle_route_req")

t.addChannel("handle_route_req", out)

print("Activate debug message on channel handle_route_reply")

t.addChannel("handle_route_reply", out)

# Create nodes


# Create node 1

print("Creating node 1")

node0 = t.getNode(1)

time0 = 0*t.ticksPerSecond()

node0.bootAtTime(time0)

print(">>>Node 1 boots at time",  time0/t.ticksPerSecond(), "[sec]")


# Create node 2

print("Creating node 2")

node1 = t.getNode(2)

time1 = 0*t.ticksPerSecond()

node1.bootAtTime(time1)

print(">>>Node 2 boots at time",  time1/t.ticksPerSecond(), "[sec]")


# Create node 3

print("Creating node 3")

node2 = t.getNode(3)

time2 = 0*t.ticksPerSecond()

node2.bootAtTime(time2)

print(">>>Node 3 boots at time",  time2/t.ticksPerSecond(), "[sec]")

# Create node 4

print("Creating node 4")

node3 = t.getNode(4)

time3 = 0*t.ticksPerSecond()

node3.bootAtTime(time3)

print(">>>Node 4 boots at time",  time3/t.ticksPerSecond(), "[sec]")

# Create node 5

print("Creating node 5")

node4 = t.getNode(5)

time4 = 0*t.ticksPerSecond()

node4.bootAtTime(time4)

print(">>>Node 5 boots at time",  time4/t.ticksPerSecond(), "[sec]")

# Create node 6

print("Creating node 6")

node5 = t.getNode(6)

time5 = 0*t.ticksPerSecond()

node5.bootAtTime(time5)

print(">>>Node 6 boots at time",  time5/t.ticksPerSecond(), "[sec]")

# Create node 7

print("Creating node 7")

node6 = t.getNode(7)

time6 = 0*t.ticksPerSecond()

node6.bootAtTime(time6)

print(">>>Node 7 boots at time",  time6/t.ticksPerSecond(), "[sec]")


print("Creating radio channels...")

f = open(topofile, "r")

lines = f.readlines()

for line in lines:

    s = line.split()

    if (len(s) > 0):

        print(">>>Setting radio channel from node ",
              s[0], " to node ", s[1], " with gain ", s[2], " dBm")

        radio.add(int(s[0]), int(s[1]), float(s[2]))


# creation of channel model

print("Initializing Closest Pattern Matching (CPM)...")

noise = open(modelfile, "r")

lines = noise.readlines()

compl = 0

mid_compl = 0


print("Reading noise model data file:", modelfile)

print("Loading:")

for line in lines:

    str = line.strip()

    if (str != "") and (compl < 10000):

        val = int(str)

        mid_compl = mid_compl + 1

        if (mid_compl > 5000):

            compl = compl + mid_compl

            mid_compl = 0

            sys.stdout.write("#")

            sys.stdout.flush()

        for i in range(1, 8):

            t.getNode(i).addNoiseTraceReading(val)

print("Done!")


for i in range(1, 8):

    print(">>>Creating noise model for node:", i)

    t.getNode(i).createNoiseModel()


print("Start simulation with TOSSIM! \n\n\n")


for i in range(0, 1000):

    t.runNextEvent()

print("\n\n\nSimulation finished!")
