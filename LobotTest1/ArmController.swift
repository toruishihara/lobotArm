//
//  ArmController.swift
//  LobotTest1
//
//  Created by sbdev on 3/2/19.
//  Copyright © 2019 any. All rights reserved.
//

import Foundation
import CoreBluetooth

class ArmController : NSObject {
    init(peripheral peri:CBPeripheral, servoChar ch:CBCharacteristic) {
        _peripheral = peri
        _char = ch
    }
    var _peripheral:CBPeripheral
    var _char:CBCharacteristic
    var _timer:Timer?

    var _angleInit = 0
    var _cnt = 0
    var _cnt2 = 0
    var _angle1:Double = 180.0
    var _angle2:Double = 70.0 //160.0
    var _angle3:Double = 120.0
    var _angle4:Double = 120.0
    var _angle5:Double = 124.0 //59.0
    var _angle6:Double = 90.0
    
    func Start() {
        DispatchQueue.main.async {
            _ = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.TimerCallback), userInfo: nil, repeats: true)
        }
        print("timer start")

    }
    func initAngle() {
        print("initAngle")
        //moveServo(id:1, angle:_angle1, time:1000)
        moveServo(id:2, angle:_angle2, time:1000)
        moveServo(id:3, angle:_angle3, time:1000)
        moveServo(id:4, angle:_angle4, time:1000)
        moveServo(id:5, angle:_angle5, time:1000)
        moveServo(id:6, angle:_angle6, time:1000)
    }
    var _d5b:Double = 72.0
    var _d54:Double = 96.0
    var _d43:Double = 96.0
    var _d32:Double = 96.0
    var _d20:Double = 96.0
    
    func cosFomula(len1 a:Double, len2 b:Double, len3 c:Double, valid:inout Bool) -> (Double) {
        let val = (a*a + b*b - c*c)/(2.0*a*b)
        if (val > 1.0 || val < -1.0) {
            print("cosFomula error")
            valid = false
            return (0.0)
        }
        let gamma = acos(val)
        return (gamma)
    }
    
    func calc2DPos(th5: Double, th4: Double, th3: Double) -> (Double, Double) {
        let p5x = 0.0
        let p5y = _d5b
        let p4x = p5x + _d54*sin(th5*Double.pi/180.0)
        let p4y = p5y + _d54*cos(th5*Double.pi/180.0)
        let th54 = th4 + th5
        let p3x = p4x + _d43*sin(th54*Double.pi/180.0)
        let p3y = p4y + _d43*cos(th54*Double.pi/180.0)
        let th543 = th3 + th4 + th5
        let p2x = p3x + _d32*sin(th543*Double.pi/180.0)
        let p2y = p3y + _d32*cos(th543*Double.pi/180.0)
        let th54390 = th3 + th4 + th5 + 90.0
        let p0x = p2x + _d20*sin(th54390*Double.pi/180.0)
        let p0y = p2y + _d20*cos(th54390*Double.pi/180.0)
        return (p0x, p0y)
    }
    func calcThExtend(len: Double, z:Double) -> (Double, Double, Double, Bool) {
        let r:Double = sqrt((len - _d32)*(len - _d32) + (z + _d20 - _d5b)*(z + _d20 - _d5b))
        print("r=\(r)")
        let tmp = 0.5*r/_d54
        if (tmp > 1.0 || tmp < -1.0) {
            print("error tmp00=\(tmp)")
            return (0.0, 0.0, 0.0, false)
        }
        let thd = acos(tmp)
        let thdangle = thd*180.0/Double.pi
        print("thdangle=\(thdangle)")
        let th4 = 2*thd
        let th4angle = th4*180.0/Double.pi
        print("th4angle=\(th4angle)")
        let tmp2 = (len - _d32)/r
        if (tmp2 > 1.0 || tmp2 < -1.0) {
            print("error tmp02=\(tmp2)")
            return (0.0, 0.0, 0.0, false)
        }
        let th5 = asin(tmp2) - thd
        let th5angle = th5*180.0/Double.pi
        print("th5angle=\(th5angle)")
        let th3 = 0.5*Double.pi - th4 - th5
        let th3angle = th3*180.0/Double.pi
        print("th3angle=\(th3angle)")
        return (th3angle, th4angle, th5angle, true)
    }
    func calcThFold(len: Double, z:Double) -> (Double, Double, Double, Bool) {
        let s:Double = sqrt(_d20*_d20 + _d32*_d32)
        let b:Double = _d32
        var valid:Bool = true
        let t = sqrt(len*len + (_d5b - z)*(_d5b - z))
        
        let th3 = Double.pi*120.0/180.0 - cosFomula(len1:b, len2:s, len3:t, valid:&valid) - asin(_d20/s)
        print("new=\(th3)")
        if (valid == false) {
            return (0.0, 0.0, 0.0, false)
        }
        let th3angle = th3*180.0/Double.pi
        print("th3angle=\(th3angle)")
        let th5 = Double.pi/6.0 - cosFomula(len1:b, len2:t, len3:s, valid:&valid) + asin((_d5b - z)/t)
        let th5angle = th5*180.0/Double.pi
        print("th5angle=\(th5angle)")
        if (th3angle > 30.0) {
            return (th3angle, 120.0, th5angle, false)
        } else {
            return (th3angle, 120.0, th5angle, true)
        }
    }
    
    func calcThFromXYZ(x: Double, y:Double, z:Double) -> (Double, Double, Double, Double, Bool) {
        var th3:Double
        var th4:Double
        var th5:Double
        var valid:Bool
        let len = sqrt(x*x + y*y)
        let th6 = asin(y/len)*180.0/Double.pi
        (th3,th4,th5,valid) = calcThFold(len:len, z:z)
        if (th5 > 20.0 || valid == false) {
            print("Extend")
            (th3, th4, th5, valid) = calcThExtend(len:len, z:z)
            return (th3, th4, th5, th6, valid)
        } else {
            print("Fold")
            return (th3, th4, th5, th6, valid)
        }
    }
    
    @objc func TimerCallback() {
        print("update")
        var myCnt = 0
        var valid:Bool
        if (_char == nil || _cnt == 0) {
            if (_cnt2 < 20) {
                var th30:Double
                var th40:Double
                var th50:Double
                let x0:Double = 100.0 + 5.0*Double(_cnt2)
                //(th30,th40,th50,valid) = calcThFromXY(x:x0, y:20.0)
                //print("th30=\(th30) th40=\(th40) th50=\(th50) valid=\(valid)")
            }
            _cnt2 = _cnt2 + 1
        }
        if (_char != nil) {
            if (_angleInit == 0) {
                initAngle()
                _angleInit = 1
            }
            if (myCnt <= 100 && _cnt % 5 == 2) {
                var th3:Double
                var th4:Double
                var th5:Double
                var th6:Double
                myCnt = _cnt/5
                (th3,th4,th5,th6,valid) = calcThFromXYZ(x:100.0 + 10.0*Double(myCnt%10), y:-50 + 10.0*Double(myCnt/10), z:20.0)
                print("cnt=\(myCnt) th3=\(th3) th4=\(th4) th5=\(th5) valid=\(valid)")
                if (valid == false) {
                    return
                }
                moveServo(id:6, angle: -1.0*th6 + _angle6, time:500)
                moveServo(id:5, angle: -1.0*th5 + _angle5, time:500)
                moveServo(id:4, angle:  1.0*th4 + _angle4, time:500)
                moveServo(id:3, angle: -1.0*th3 + _angle3, time:500)
            }
            if (myCnt <= 100 && _cnt % 5 == 3) {
                var th3:Double
                var th4:Double
                var th5:Double
                var th6:Double
                myCnt = _cnt/5
                (th3,th4,th5,th6,valid) = calcThFromXYZ(x:100.0 + 10.0*Double(myCnt%10), y:-50 + 10.0*Double(myCnt/10), z:0.0)
                print("cnt=\(myCnt) th3=\(th3) th4=\(th4) th5=\(th5) valid=\(valid)")
                if (valid == false) {
                    return
                }
                moveServo(id:6, angle: -1.0*th6 + _angle6, time:500)
                moveServo(id:5, angle: -1.0*th5 + _angle5, time:500)
                moveServo(id:4, angle:  1.0*th4 + _angle4, time:500)
                moveServo(id:3, angle: -1.0*th3 + _angle3, time:500)
            }
            _cnt = _cnt + 1
        }
    }
    func moveServo(id: UInt, angle: Double, time: UInt) -> Void {
        //var theData : [UInt8] = [ 0x55, 0x55, 0x08, 0x03, 0x01, 0x96, 0x00, 0x01, 0x4b, 0x01 ]
        var theData : [UInt8] = [ 0x55, 0x55, 0x08, 0x03, 0x01, 0x96, 0x00, 0x01, 0x4b, 0x01 ]
        //let sum:UInt8 = LobotCheckSum(buf: theData)
        //print("sum=\(sum)")
        theData[5] = UInt8(time & 0x00ff)
        theData[6] = UInt8((time>>8) & 0x00ff)
        theData[7] = UInt8(id)
        let angleInt:UInt16 = UInt16(angle/0.24)
        theData[8] = UInt8(angleInt & 0x00ff)
        theData[9] = UInt8((angleInt>>8) & 0x00ff)
        let data = NSData(bytes: &theData, length: theData.count)
        _peripheral.writeValue(data as Data, for:_char, type: CBCharacteristicWriteType.withResponse)
    }

}
