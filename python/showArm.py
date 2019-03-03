import math
import sqlite3
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D

c = sqlite3.connect('/Users/sbdev/Documents/xarm.db')
for row in c.execute('SELECT * FROM angles where id=1'):
    angle1 = float(row[1])
    angle2 = float(row[2])
    angle3 = float(row[3])
    angle4 = float(row[4])
    angle5 = float(row[5])
    angle6 = float(row[6])

print(angle1, angle2, angle3, angle4, angle5, angle6)
ra = math.pi/180.0
th2 = ra*90.0
th3 = -1.0*ra*angle3
th4 = ra*angle4
th5 = -1.0*ra*angle5
len56 = 73.0
len45 = 96.0
len34 = 96.0
len23 = 100.0
len12 = 148.0

fig = plt.figure()
ax = fig.add_subplot(111, projection='3d')
ax.set_xlim3d(-200,200)
ax.set_ylim3d(-200,200)
ax.set_zlim3d(0,400)

p6 = [0,0,0]
p5 = [0,0,len56]
p4 = [p5[0] + len45*math.sin(th5), p5[1], p5[2] + len45*math.cos(th5)]
p3 = [p4[0] + len34*math.sin(th5+th4), p4[1], p4[2] + len34*math.cos(th5+th4)]
p2 = [p3[0] + len23*math.sin(th5+th4+th3), p3[1], p3[2] + len23*math.cos(th5+th4+th3)]
p1 = [p2[0] + len12*math.sin(th5+th4+th3+th2), p2[1], p2[2] + len12*math.cos(th5+th4+th3+th2)]
ax.plot([p6[0],p5[0]], [p6[1],p5[1]], zs=[p6[2],p5[2]])
ax.plot([p5[0],p4[0]], [p5[1],p4[1]], zs=[p5[2],p4[2]])
ax.plot([p4[0],p3[0]], [p4[1],p3[1]], zs=[p4[2],p3[2]])
ax.plot([p3[0],p2[0]], [p3[1],p2[1]], zs=[p3[2],p2[2]])
ax.plot([p2[0],p1[0]], [p2[1],p1[1]], zs=[p2[2],p1[2]])

plt.show()
Axes3D.plot()
