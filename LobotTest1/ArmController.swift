//
//  ArmController.swift
//  LobotTest1
//
//  Created by sbdev on 3/2/19.
//  Copyright © 2019 any. All rights reserved.
//

import Foundation
import AppKit
import CoreBluetooth
import SQLite3

class ArmController : NSObject {
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
    var _d20:Double = 105.0 // pencil length

    // Calibrated angle
    var _angleInited = 0
    var _angle1:Double = 0.0   // not used
    var _angle2:Double = 70.0  // pencil down vertically
    var _angle3:Double = 120.0 // straight line
    var _angle4:Double = 123.0 // straight line
    var _angle5:Double = 121.0 // straight up
    var _angle6:Double = 160.0
    
    func Start() {
        DispatchQueue.main.async {
            _ = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.TimerCallback), userInfo: nil, repeats: true)
        }
        print("timer start")
        _db = openDatabase()
    }
    func initAngle1() {
        print("initAngle1")
        //moveServo(id:1, angle:_angle1, time:1000)
        moveServo(id:2, angle:_angle2, time:1000)
        moveServo(id:3, angle:_angle3, time:1000)
        moveServo(id:4, angle:_angle4, time:1000)
        moveServo(id:5, angle:_angle5, time:1000)
        moveServo(id:6, angle:_angle6, time:1000)
    }
    func initAngle2() {
        print("initAngle2")
        //moveServo(id:1, angle:_angle1, time:1000)
        moveServo(id:2, angle:_angle2, time:1000)
        moveServo(id:3, angle:_angle3+30, time:1000)
        moveServo(id:4, angle:_angle4+30, time:1000)
        moveServo(id:5, angle:_angle5+30, time:1000)
        moveServo(id:6, angle:_angle6, time:1000)
    }
    func initAngle3() {
        print("initAngle3")
        //moveServo(id:1, angle:_angle1, time:1000)
        moveServo(id:2, angle:_angle2, time:1000)
        moveServo(id:3, angle:_angle3+60, time:1000)
        moveServo(id:4, angle:_angle4+60, time:1000)
        moveServo(id:5, angle:_angle5+60, time:1000)
        moveServo(id:6, angle:_angle6+30, time:1000)
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
    var _cnt = 0
    var _th3:Double = 0.0
    var _th4:Double = 0.0
    var _th5:Double = 0.0
    var _th6:Double = 0.0
    var _valid:Bool = true
    func test_mesh_touch() {
        let start_x = 120.0
        let end_x = 200.0
        let start_y = 0.0
        let end_y = 50.0
        let inc_xy = 10.0
        var myCnt:Int
        
        if (_cnt % 5 == 1) {
            myCnt = _cnt/5
            let myMod = Int((end_x - start_x)/inc_xy + 1)
            let x = start_x + inc_xy*Double(myCnt % myMod)
            let y = start_y + inc_xy*Double(myCnt / myMod)
            if (x > end_x || y > end_y) {
                return
            }
            var z:Double
            if (x > 170) { // temporary adjustment
                z = 42.0
            } else {
                z = 42.0
            }
            (_th3, _th4, _th5, _th6, _valid) = calcThFromXYZ(x:x, y:y, z:z)
            print("cnt=\(myCnt) th3=\(Int(_th3)) th4=\(Int(_th4)) th5=\(Int(_th5)) valid=\(_valid)")
            if (_valid == false) {
                return
            }
            moveServo(id:2, angle: _angle2 - 0.0, time:500)
            moveServo(id:6, angle: -1.0*_th6 + _angle6, time:500)
            moveServo(id:5, angle:  1.0*_th5 + _angle5, time:500)
            moveServo(id:4, angle: -1.0*_th4 + _angle4, time:500)
            moveServo(id:3, angle:  1.0*_th3 + _angle3 - 30.0, time:500)
            updateSqlite(ang1:nil, ang2:nil, ang3:_th3, ang4:_th4, ang5:_th5, ang6:_th6)
        }
        if (_cnt % 5 == 2) {
            moveServo(id:2, angle: _angle2, time:1000)
            moveServo(id:3, angle: 1.0*_th3 + _angle3 - 0.0, time:1000)
        }
        if (_cnt % 5 == 3) {
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            if (appDelegate._currentWeight != nil && appDelegate._currentWeight! < 100) {
                print("\(appDelegate._currentWeight!) more push")
                moveServo(id:3, angle: 1.0*_th3 + _angle3 - 1.0, time:1000)
            }
        }
        if (_cnt % 5 == 3) {
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            if (appDelegate._currentWeight != nil && appDelegate._currentWeight! < 100) {
                print("\(appDelegate._currentWeight!) 2 more push")
                moveServo(id:3, angle: 1.0*_th3 + _angle3 - 2.0, time:1000)
            }
        }
    }
    func calibrate() {
        if (_cnt == 0) {
            initAngle1()
        }
        if (_cnt == 5) {
            initAngle2()
        }
        if (_cnt == 10) {
            initAngle3()
        }
    }
    @objc func TimerCallback() {
        print("update")
        if (_cnt == 0) {
          calibrate()
        }
        test_mesh_touch()
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

    func updateSqliteOneAngle(id:Int, angle:Double?) -> Void {
        if (_db == nil || angle == nil) {
            return
        }
        if (angle! < -180.0 || angle! > 180.0) {
            return
        }
        let cmd = NSString(format: "update angles set angle%d=%.2f where id=1", id, angle!)
        if sqlite3_exec(_db, cmd.cString(using: String.Encoding.utf8.rawValue), nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(_db)!)
            print("error update table: \(errmsg)")
        }
    }
    
    func updateSqlite(ang1:Double?, ang2:Double?, ang3:Double?, ang4:Double?, ang5:Double?, ang6:Double?) -> Void {
        updateSqliteOneAngle(id:1, angle:ang1)
        updateSqliteOneAngle(id:2, angle:ang2)
        updateSqliteOneAngle(id:3, angle:ang3)
        updateSqliteOneAngle(id:4, angle:ang4)
        updateSqliteOneAngle(id:5, angle:ang5)
        updateSqliteOneAngle(id:6, angle:ang6)
    }
    
    func openDatabase() -> OpaquePointer? {
        
        let fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("xarm.db")
        
        // open database
        
        var db: OpaquePointer?
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("error opening database")
        }
        if sqlite3_exec(db, "create table if not exists angles (id integer primary key, angle1 text, angle2 text, angle3 text, angle4 text, angle5 text, angle6 text)", nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error creating table: \(errmsg)")
        }
        if sqlite3_exec(db, "insert into angles values(1,0,0,0,0,0,0)", nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error insert into table: \(errmsg)")
        }
        return db
    }
}
