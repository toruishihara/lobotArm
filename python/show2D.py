import math
import sqlite3
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation

fig, ax = plt.subplots()
#plt.plot(range(500))
plt.xlim(-300, 300)
plt.ylim(-300, 300)
plt.gca().set_aspect('equal', adjustable='box')

ra = math.pi/180.0
len56 = 73.0
len45 = 96.0
len34 = 96.0
len23 = 100.0
len12 = 148.0

p6 = [0,0,0]
p5 = [0,0,len56]
p4 = [0,0,0]
p3 = [0,0,0]
p2 = [0,0,0]
p1 = [0,0,0]
line, = ax.plot([p6[0], p5[0], p4[0], p3[0], p2[0], p1[0]], [p6[2], p5[2], p4[2], p3[2], p2[2], p1[2]])

def init():
    p1,p2,p3,p4 = read_calc()
    line.set_xdata([p6[0], p5[0], p4[0], p3[0], p2[0], p1[0]])
    line.set_ydata([p6[2], p5[2], p4[2], p3[2], p2[2], p1[2]])
    return line,

def read_calc():
    c = sqlite3.connect('/Users/sbdev/Documents/xarm.db')
    for row in c.execute('SELECT * FROM angles where id=1'):
        angle1 = float(row[1])
        angle2 = float(row[2])
        angle3 = float(row[3])
        angle4 = float(row[4])
        angle5 = float(row[5])
        angle6 = float(row[6])
    c.close()
    print(angle1, angle2, angle3, angle4, angle5, angle6)
    th2 = ra*90.0
    th3 = -1.0*ra*angle3
    th4 = ra*angle4
    th5 = ra*angle5
    p4 = [p5[0] + len45*math.sin(th5), p5[1], p5[2] + len45*math.cos(th5)]
    p3 = [p4[0] + len34*math.sin(th5+th4), p4[1], p4[2] + len34*math.cos(th5+th4)]
    p2 = [p3[0] + len23*math.sin(th5+th4+th3), p3[1], p3[2] + len23*math.cos(th5+th4+th3)]
    p1 = [p2[0] + len12*math.sin(th5+th4+th3+th2), p2[1], p2[2] + len12*math.cos(th5+th4+th3+th2)]
    return p1,p2,p3,p4

def animate(i):
    p1,p2,p3,p4 = read_calc()
    print(p4[0], p3[0], p2[0])
    print(p4[2], p3[2], p2[2])
    line.set_xdata([p6[0], p5[0], p4[0], p3[0], p2[0], p1[0]])
    line.set_ydata([p6[2], p5[2], p4[2], p3[2], p2[2], p1[2]])
    return line,

ani = animation.FuncAnimation(
    fig, animate, init_func=init, interval=1000, blit=True, save_count=50)

plt.show()
