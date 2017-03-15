import operator
a_ips = {}
e_ips = {}
count = 0
for line in open("/Users/wileyj/Downloads/access_log/access_log", 'r'):
    ip = line.split(' ')[0]
    tokens = line.split(' ')
    print "tokens len: %i" % (len(tokens))
    for i in range(0,len(tokens)):
        print "\t %s" % (tokens[i])
    count = 1
    try:
        if ip in a_ips:
            count = a_ips[ip] + 1
            a_ips[ip] = count
    except:
        pass
    a_ips[ip] = count
this = sorted(
    a_ips.items(),
    key=operator.itemgetter(1),
    reverse=True
)

# length = len(this)
# print length
# if length > 10:
    # length = 10
# for i in xrange(0,length):
    # print this[i]
