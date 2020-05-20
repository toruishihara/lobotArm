//
//  ArmClawController.swift
//  LobotTest1
//
//  Created by TORU ISHIHARA on 5/16/20.
//  Copyright © 2020 Actiontec. All rights reserved.
//

import Foundation
import AppKit
import CoreBluetooth
import SQLite3

class ArmClawController : NSObject {
    init(peripheral peri:CBPeripheral?, servoChar ch:CBCharacteristic?) {
        _peripheral = peri
        _char = ch
    }
    // config
    var _sendToBLE:Bool = true
    
    var _peripheral:CBPeripheral?
    var _char:CBCharacteristic?
    var _timer:Timer?
    var _db:OpaquePointer? // sqlite3 db

    // Arm length in mm
    var _d5b:Double = 73.0 // Base table and ID5 servo height
    var _d54:Double = 96.0 // Leg ID5 servo and ID4
    var _d43:Double = 96.0 // Leg ID4 servo and ID3
    var _d32:Double = 100.0 // Leg ID3 servbo and pencil top
    var _d20:Double = 115.0 // pencil length

    // Calibrated angle
    var _angleInited = 0
    var _angle1:Double = 120.0   // Claw open/close
    var _angle2:Double = 170.0  // Claw angle
    var _angle3:Double = 120.0 // straight line
    var _angle4:Double = 123.0 // straight line
    var _angle5:Double = 121.0 // 121 straight up
    var _angle6:Double = 160.0
    
    var _interval:UInt = 2000
    func Start() {
        DispatchQueue.main.async {
            _ = Timer.scheduledTimer(timeInterval: 1.0/* sec */, target: self, selector: #selector(self.TimerCallback), userInfo: nil, repeats: true)
        }
        print("timer start")
        //_db = openDatabase()
    }
    func initAngle1() {
        print("initAngle1")
        moveServo(id:1, angle:_angle1, time:_interval)
        moveServo(id:2, angle:_angle2, time:_interval)
        moveServo(id:3, angle:_angle3, time:_interval)
        moveServo(id:4, angle:_angle4, time:_interval)
        moveServo(id:5, angle:_angle5, time:_interval)
        moveServo(id:6, angle:_angle6, time:_interval)
    }
    func initAngle2() {
        print("initAngle2")
        moveServo(id:1, angle:_angle1, time:_interval)
        moveServo(id:2, angle:_angle2, time:_interval)
        moveServo(id:3, angle:_angle3, time:_interval)
        moveServo(id:4, angle:_angle4, time:_interval)
        moveServo(id:5, angle:_angle5, time:_interval)
        moveServo(id:6, angle:_angle6, time:_interval)
    }

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
        print("l=\(len) z=\(z) r=\(r)")
        let tmp = 0.5*r/_d54
        if (tmp > 1.0 || tmp < -1.0) {
            print("error tmp00=\(tmp)")
            return (0.0, 0.0, 0.0, false)
        }
        let thd = acos(tmp) // angle P3-P5-P4
        let thdangle = thd*180.0/Double.pi
        print("thdangle=\(Int(thdangle))")
        let th4 = 2*thd
        let th4angle = th4*180.0/Double.pi
        print("th4angle=\(Int(th4angle))")
        let tmp2 = (len - _d32)/r
        if (tmp2 > 1.0 || tmp2 < -1.0) {
            print("error tmp02=\(tmp2)")
            return (0.0, 0.0, 0.0, false)
        }
        let th5_thd = asin(tmp2)*180.0/Double.pi
        let th5 = asin(tmp2) - thd
        let th5angle = th5*180.0/Double.pi
        print("th5angle=\(Int(th5angle))")
        let th3 = 0.5*Double.pi - th4 - th5
        let th3angle = th3*180.0/Double.pi
        print("th3angle=\(Int(th3angle))")
        return (th3angle, th4angle, th5angle, true)
    }
    func calcThFold(len: Double, z:Double) -> (Double, Double, Double, Bool) {
        let s:Double = sqrt(_d20*_d20 + _d32*_d32)
        let b:Double = _d32
        var valid:Bool = true
        let t = sqrt(len*len + (_d5b - z)*(_d5b - z))
        
        let th3 = Double.pi*120.0/180.0 - cosFomula(len1:b, len2:s, len3:t, valid:&valid) - asin(_d20/s)
        print("new=\(Int(th3))")
        if (valid == false) {
            return (0.0, 0.0, 0.0, false)
        }
        let th3angle = th3*180.0/Double.pi
        print("th3angle=\(Int(th3angle))")
        let th5 = Double.pi/6.0 - cosFomula(len1:b, len2:t, len3:s, valid:&valid) + asin((_d5b - z)/t)
        let th5angle = th5*180.0/Double.pi
        print("th5angle=\(Int(th5angle))")
        if (th3angle > 120.0 || th3angle < -30.0) {
            return (th3angle, 120.0, th5angle, false)
        } else {
            return (th3angle, 120.0, th5angle, true)
        }
    }
    
    func calcThFromXYZ(x: Double, y:Double, z:Double) -> (Double, Double, Double, Double, Bool) {
        var th3:Double
        var th4:Double
        var th5:Double
        var valid:Bool = true
        print("XYZ=\(Int(x)), \(Int(y)), \(Int(z))")
        let len = sqrt(x*x + y*y)
        let th6 = asin(y/len)*180.0/Double.pi
        (th3,th4,th5,valid) = calcThExtend(len:len, z:z)
        if (valid == false || th4 > 120.0) {
            print("Fold")
            valid = true
            (th3, th4, th5, valid) = calcThFold(len:len, z:z)
            return (th3, th4, th5, th6, valid)
        } else {
            print("Extend")
            return (th3, th4, th5, th6, valid)
        }
    }
    func moveXYZ(x: Double, y:Double, z:Double) {
        var th3:Double
        var th4:Double
        var th5:Double
        var th6:Double
        var valid:Bool = true
        (th3, th4, th5, th6, valid) = calcThFromXYZ(x:x, y:y, z:z)
        print("th3=\(Int(th3)) th4=\(Int(th4)) th5=\(Int(th5)) th5=\(Int(th6)) valid=\(valid)")
        if (valid == false) {
            return
        }
        moveServo(id:2, angle: _angle2 - 0.0, time:_interval)
        moveServo(id:6, angle: -1.0*th6 + _angle6, time:_interval)
        moveServo(id:5, angle:  1.0*th5 + _angle5, time:_interval)
        moveServo(id:4, angle: -1.0*th4 + _angle4, time:_interval)
        moveServo(id:3, angle:  1.0*th3 + _angle3 - 10.0, time:_interval)
    }
    let _start_x = 200.0
    let _start_y = 0.0

    var _cnt = 0

    var _isUp = false
    
    func open_claw() {
        _angle1 = 120
        print("open")
        moveServo(id:1, angle: _angle1, time:1*_interval)
    }
    
    func close_claw(){
        _angle1 = 170
        print("close")
        moveServo(id:1, angle: _angle1, time:1*_interval)
    }
    
    func down() {
        _angle5 = 40
        print("down")
        moveXYZ(x: _start_x, y: _start_y, z: 0.0)
        _isUp = false
    }
    
    func up() {
        _angle5 = 70
        print("up")
        moveXYZ(x: _start_x, y: _start_y, z: 3.0)
        _isUp = true
    }
    
    func close_up_down() {
        let date = Date()
        let calendar = Calendar.current

        let hour = calendar.component(.hour, from: date)
        let minutes = calendar.component(.minute, from: date)
        let seconds = calendar.component(.second, from: date)
        //print("hours = \(hour):\(minutes):\(seconds)")
        //print("_cnt=\(_cnt)")
        if (_cnt == 5) {
            up()
        }
        if (_cnt > 10) {
            _interval = 500
            if (_cnt < 20) {
                if (_cnt % 10 == 1) {
                    up()
                }
                if (_cnt % 10 == 2) {
                    open_claw()
                }
                if (_cnt % 10 == 4) {
                    down()
                }
                if (_cnt % 10 == 8) {
                    close_claw()
                }
                if (_cnt % 10 == 9) {
                    up()
                }
            } else {
                if (minutes % 2 == 1) {
                    if (_isUp == false) {
                        print("hours = \(hour):\(minutes):\(seconds)")
                        up()
                    }
                }
                if (minutes % 2 == 0) {
                    if (_isUp == true) {
                        print("hours = \(hour):\(minutes):\(seconds)")
                        down()
                    }
                }
            }
        }
    }
    
    func test() {
        let date = Date()
        let calendar = Calendar.current

        let hour = calendar.component(.hour, from: date)
        let minutes = calendar.component(.minute, from: date)
        let seconds = calendar.component(.second, from: date)

        if (minutes % 2 == 0) {
            if (_isUp == true) {
                print("hours = \(hour):\(minutes):\(seconds)")
                print("down")
                moveServo(id:4, angle: _angle4 + 0, time:_interval)
                _isUp = false
            }
        }
        if (minutes % 2 == 1) {
            if (_isUp == false) {
                print("hours = \(hour):\(minutes):\(seconds)")
                print("up")
                moveServo(id:4, angle: _angle4 + 60, time:_interval)
                _isUp = true
            }
        }

    }
    
    @objc func TimerCallback() {
        //print("update")
        if (_cnt == 0) {
          //initAngle1()
        }
        //close_up_down()
        test()
        _cnt = _cnt + 1
    }
    func moveServo(id: UInt, angle: Double, time: UInt) -> Void {
        if (_sendToBLE == false || _peripheral == nil || _char == nil) {
            return
        }
        var theData : [UInt8] = [ 0x55, 0x55, 0x08, 0x03, 0x01, 0x96, 0x00, 0x01, 0x4b, 0x01 ]
        theData[5] = UInt8(time & 0x00ff)
        theData[6] = UInt8((time>>8) & 0x00ff)
        theData[7] = UInt8(id)
        let angleInt:UInt16 = UInt16(angle/0.24)
        theData[8] = UInt8(angleInt & 0x00ff)
        theData[9] = UInt8((angleInt>>8) & 0x00ff)
        let data = NSData(bytes: &theData, length: theData.count)
        _peripheral!.writeValue(data as Data, for:_char!, type: CBCharacteristicWriteType.withResponse)
    }
}
