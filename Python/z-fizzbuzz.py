from __future__ import division

x = 10
# print isinstance(x, (int, long))


for i in range(1,115):
    val3 = i/3
    val4 = i/4
    if val3.is_integer() and not val4.is_integer():
        print (i,val3, "fizz")
    elif val4.is_integer() and not val3.is_integer():
        print (i, val4, "buzz")
    elif val3.is_integer() and val4.is_integer():
        print (i, val3, val4, "fizzbuzz")
    else:
        print ("no match: ", i, val3, val4)
